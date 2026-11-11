//
//  SpotListViewController.swift
//  KainSpot — Controller layer
//  Lists spots from Core Data that match the user's filter, ranked by SmartRanker, with live search,
//  pull-to-refresh syncing from the web, and the 🎰 roulette.
//  Course week: Week 3 (UITableView + custom cells) and Week 5 (networking + Core Data persistence).
//  Feature: Smart ranking, Vacant Planner leave-by line, UISearchController, Roulette, animated cells.
//

import UIKit
import CoreData

/// Table of spots: Core Data predicate (kind, price, budget, WiFi, discount, trending) → distance check in
/// memory → SmartRanker ordering with whatever the student typed in the search bar.
final class SpotListViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyLabel: UILabel!
    @IBOutlet weak var bannerLabel: UILabel!

    /// Set by PreferencesViewController in prepare(for:sender:).
    var filter: SpotFilter = .default

    private let context = CoreDataStack.shared.viewContext
    private let syncService = SpotSyncService()
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)

    /// Every spot that passed the filter (before search), kept so typing re-ranks without re-fetching.
    private var filteredSpots: [Spot] = []
    /// What the table shows, best first.
    private var rows: [ScoredSpot] = []
    /// Switch names that hid every spot (each one, turned off alone, would show spots). Empty when spots exist.
    private var blockingSwitches: [String] = []
    private var isSyncing = false
    /// Spot ids that already played their entrance animation (animate on first appearance only).
    private var animatedSpotIDs = Set<String>()

    /// Data is considered fresh for one hour; older than that we re-download on open.
    private let staleInterval: TimeInterval = 60 * 60

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        let name = filter.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        title = name.isEmpty ? "Para sa'yo" : "Para sa'yo, \(name)"

        // Data source/delegate wired in code (not the storyboard) so the wiring is visible to readers.
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Theme.background
        // Taller than the original 96 pt to fit the extra "Leave by" line.
        tableView.rowHeight = 126
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.keyboardDismissMode = .onDrag

        refreshControl.tintColor = Theme.primary
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        bannerLabel.isHidden = true
        bannerLabel.backgroundColor = Theme.primaryDark
        bannerLabel.textColor = .white
        emptyLabel.textColor = Theme.muted

        configureSearch()
        configureRouletteButton()

        // Show whatever is already saved immediately, then sync only if the data is missing or stale.
        reloadSpots()
        if shouldSync() {
            runSync()
        }
    }

    /// Re-read on return from the detail screen so a newly added photo shows in the thumbnail.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selected = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selected, animated: animated)
        }
        if !rows.isEmpty {
            tableView.reloadData()
        }
    }

    /// True when we never synced or the last sync is older than an hour.
    private func shouldSync() -> Bool {
        guard let lastSync = UserPrefs.shared.lastSync else { return true }
        return Date().timeIntervalSince(lastSync) > staleInterval
    }

    // MARK: - Setup

    /// Search bar in the navigation bar; typing re-ranks live (QueryParser + SmartRanker, fully offline).
    private func configureSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Try \"kape wifi\" or \"isaw under 100\""
        searchController.searchBar.accessibilityIdentifier = "spotSearch"
        searchController.searchBar.searchTextField.accessibilityIdentifier = "spotSearch"
        searchController.searchBar.tintColor = Theme.primary
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    /// "🎰" in the top-right opens the roulette with the current results.
    private func configureRouletteButton() {
        let roulette = UIBarButtonItem(title: "🎰", style: .plain, target: self, action: #selector(rouletteTapped))
        roulette.accessibilityIdentifier = "rouletteButton"
        roulette.accessibilityLabel = "Can't decide? Spin the roulette"
        navigationItem.rightBarButtonItem = roulette
    }

    // MARK: - Data

    /// Step 1: Core Data does the cheap yes/no checks and the distance check runs in memory (haversine).
    /// Step 2 (rank) orders what is left.
    private func reloadSpots() {
        filteredSpots = fetchSpots(matching: filter)

        // If nothing matched, find which yes/no switch is hiding everything (e.g. no spot has a
        // confirmed student discount yet) so the empty message can tell the student what to turn off.
        blockingSwitches = filteredSpots.isEmpty
            ? filter.relaxedSwitches().filter { !fetchSpots(matching: $0.filter).isEmpty }.map { $0.name }
            : []
        rank()
    }

    /// Core Data fetch for the database-checkable fields, then the in-memory distance check.
    private func fetchSpots(matching filter: SpotFilter) -> [Spot] {
        let request = NSFetchRequest<Spot>(entityName: "Spot")
        request.predicate = filter.predicate()
        request.sortDescriptors = [
            NSSortDescriptor(key: "rating", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]

        let fetched: [Spot]
        do {
            fetched = try context.fetch(request)
        } catch {
            print("SpotList fetch failed: \(error.localizedDescription)")
            fetched = []
        }
        return fetched.filter { spot in
            filter.matches(distanceKm: KainNavigator.distanceKm(to: spot))
        }
    }

    /// Ranks with the current search text (empty text = rank on the saved filter alone).
    private func rank() {
        let text = searchController.searchBar.text ?? ""
        let query = QueryParser.parse(text)
        rows = SmartRanker.rank(spots: filteredSpots,
                                query: query,
                                filter: filter,
                                distanceFrom: DistanceCalculator.feuDiliman,
                                now: Date())
        tableView.reloadData()
        updateEmptyState()
    }

    /// The empty message only makes sense once we are not in the middle of downloading.
    private func updateEmptyState() {
        emptyLabel.text = SpotFilter.emptyMessage(blocking: blockingSwitches)
        emptyLabel.isHidden = !rows.isEmpty || isSyncing
    }

    @objc private func pullToRefresh() {
        runSync()
    }

    /// Downloads the latest spots. On failure the service has already seeded/kept local data,
    /// so we just show a gentle offline banner instead of an error alert.
    private func runSync() {
        guard !isSyncing else { return }
        isSyncing = true
        updateEmptyState()

        syncService.sync { [weak self] result in
            // The service promises the main queue, but hopping again keeps UI updates safe regardless.
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSyncing = false
                switch result {
                case .success:
                    self.setBanner(visible: false)
                case .failure(let error):
                    print("Spot sync failed: \(error.localizedDescription)")
                    self.setBanner(visible: true)
                }
                self.refreshControl.endRefreshing()
                self.reloadSpots()
            }
        }
    }

    /// Animates the banner in/out; it lives in a stack view so hiding it collapses the space.
    private func setBanner(visible: Bool) {
        guard bannerLabel.isHidden == visible else { return }
        UIView.animate(withDuration: 0.25) {
            self.bannerLabel.isHidden = !visible
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Roulette

    /// Presents the roulette over the current results; "Let's go!" pushes the detail on our nav stack.
    @objc private func rouletteTapped() {
        Theme.hapticLight()
        let candidates = rows.map { $0.spot }
        let roulette = RouletteViewController(candidates: candidates)
        let vacant = filter.vacantMinutes
        roulette.onLetsGo = { [weak self] spot in
            self?.openDetail(for: spot, vacantMinutes: vacant)
        }
        // Searching keeps the search controller "presenting"; present from it so UIKit doesn't complain.
        let presenter: UIViewController = searchController.isActive ? searchController : self
        presenter.present(roulette, animated: true)
    }

    /// Opens a spot from code (roulette) using the storyboard detail scene.
    private func openDetail(for spot: Spot, vacantMinutes: Int) {
        guard let detail = KainNavigator.makeDetail(for: spot, vacantMinutes: vacantMinutes) else { return }
        navigationController?.pushViewController(detail, animated: true)
    }

    // MARK: - Navigation

    /// Hands the tapped Core Data object (and the vacant length) to the detail screen.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard segue.identifier == "showSpotDetail",
              let dest = segue.destination as? SpotDetailViewController,
              let spot = sender as? Spot else { return }
        dest.spot = spot
        dest.vacantMinutes = filter.vacantMinutes
    }
}

// MARK: - UITableViewDataSource

extension SpotListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    /// Dequeues the storyboard prototype and loads the user's own photo for that spot if they saved one.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotCell", for: indexPath) as? SpotCell,
              indexPath.row < rows.count else {
            return UITableViewCell()
        }
        let row = rows[indexPath.row]
        let spotID = row.spot.id ?? ""
        let photo = spotID.isEmpty ? nil : PhotoStore.spotPhotos.load(named: "spot-\(spotID).jpg")
        // Re-plan with the filter's vacant so the leave-by time matches what the student chose.
        let plan = KainNavigator.plan(for: row.spot, vacantMinutes: filter.vacantMinutes)
        cell.configure(with: row.spot, plan: plan, photo: photo)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SpotListViewController: UITableViewDelegate {

    /// Manual segue with the Spot as sender, so prepare(for:sender:) can pass it on.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < rows.count else { return }
        Theme.hapticLight()
        performSegue(withIdentifier: "showSpotDetail", sender: rows[indexPath.row].spot)
    }

    /// Cards fade and slide up the first time each spot appears (not on every scroll).
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row < rows.count else { return }
        let id = rows[indexPath.row].spot.id ?? "\(indexPath.row)"
        guard !animatedSpotIDs.contains(id) else { return }
        animatedSpotIDs.insert(id)
        Theme.animateIn(cell.contentView, delay: min(Double(indexPath.row) * 0.06, 0.4), offset: 24)
    }
}

// MARK: - UISearchResultsUpdating

extension SpotListViewController: UISearchResultsUpdating {
    /// Every keystroke re-parses the text and re-ranks the already-filtered spots (no network, instant).
    func updateSearchResults(for searchController: UISearchController) {
        rank()
    }
}
