//
//  SpotListViewController.swift
//  KainSpot — Controller layer
//  Lists food spots from Core Data that match the user's filter, with pull-to-refresh syncing from the web.
//  Course week: Week 3 (UITableView + custom cells) and Week 5 (networking + Core Data persistence).
//

import UIKit
import CoreData

/// Table of spots filtered by price/trending (Core Data predicate) and distance (in memory).
final class SpotListViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyLabel: UILabel!
    @IBOutlet weak var bannerLabel: UILabel!

    /// Set by PreferencesViewController in prepare(for:sender:).
    var filter: SpotFilter = .default

    /// One visible row: the managed object plus its pre-computed distance from FEU Diliman.
    private struct Row {
        let spot: Spot
        let distanceKm: Double
    }

    private let context = CoreDataStack.shared.viewContext
    private let syncService = SpotSyncService()
    private let refreshControl = UIRefreshControl()
    private var rows: [Row] = []
    private var isSyncing = false

    /// Data is considered fresh for one hour; older than that we re-download on open.
    private let staleInterval: TimeInterval = 60 * 60

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        let name = filter.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        title = name.isEmpty ? "Spots" : "Spots for \(name)"

        // Data source/delegate wired in code (not the storyboard) so the wiring is visible to readers.
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Theme.background
        tableView.rowHeight = 96
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        refreshControl.tintColor = Theme.primary
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        bannerLabel.isHidden = true
        bannerLabel.backgroundColor = Theme.primaryDark
        bannerLabel.textColor = .white
        emptyLabel.textColor = Theme.muted

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

    // MARK: - Data

    /// Two-step filter: Core Data handles price/trending + sorting; distance needs haversine maths so it runs in memory.
    private func reloadSpots() {
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

        rows = fetched.compactMap { spot -> Row? in
            let km = DistanceCalculator.kilometers(
                from: DistanceCalculator.feuDiliman,
                to: .init(latitude: spot.latitude, longitude: spot.longitude))
            return filter.matches(distanceKm: km) ? Row(spot: spot, distanceKm: km) : nil
        }

        tableView.reloadData()
        updateEmptyState()
    }

    /// The empty message only makes sense once we are not in the middle of downloading.
    private func updateEmptyState() {
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

    // MARK: - Navigation

    /// Hands the tapped Core Data object to the detail screen.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard segue.identifier == "showSpotDetail",
              let dest = segue.destination as? SpotDetailViewController,
              let spot = sender as? Spot else { return }
        dest.spot = spot
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
        cell.configure(with: row.spot,
                       distanceText: DistanceCalculator.formatted(row.distanceKm),
                       photo: photo)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SpotListViewController: UITableViewDelegate {

    /// Manual segue with the Spot as sender, so prepare(for:sender:) can pass it on.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < rows.count else { return }
        performSegue(withIdentifier: "showSpotDetail", sender: rows[indexPath.row].spot)
    }
}
