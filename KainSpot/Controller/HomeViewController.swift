//
//  HomeViewController.swift
//  KainSpot — Controller layer
//  Welcome screen: logo, personalised greeting, category chips, Ask Kain Spot, and the entry points
//  (Find Spots / My Food Gallery / Settings).
//  Course week: Week 1 (Auto Layout with stack views, IBOutlets/IBActions) + Week 4 (reads UserDefaults).
//  Feature: UI upgrade — category chips, "✨ Ask Kain Spot", settings gear, entrance animation.
//

import UIKit

/// Root screen inside the navigation controller.
final class HomeViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var greetingLabel: UILabel!
    @IBOutlet weak var heroImageView: UIImageView!
    @IBOutlet weak var findButton: UIButton!
    @IBOutlet weak var galleryButton: UIButton!
    @IBOutlet weak var lastSyncLabel: UILabel!

    /// Built in code and inserted into the storyboard stack (no storyboard edits needed).
    private let askButton = Theme.makePrimaryButton(title: "✨ Ask Kain Spot", identifier: "askButton")
    private let chipScrollView = UIScrollView()
    /// The entrance animation should play once per launch, not every time we pop back to Home.
    private var hasAnimatedIn = false

    /// Human-friendly date for the "Last updated" line (e.g. "Nov 10, 2026 at 3:41 PM").
    private let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// The storyboard stack that holds every Home control (found through an outlet, so no new outlet is needed).
    private var mainStack: UIStackView? {
        findButton.superview as? UIStackView
    }

    /// Applies the theme in code (corner radius, nav bar look) and adds the new programmatic controls.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        Theme.styleNavigationBar(navigationController?.navigationBar)
        Theme.stylePrimaryButton(findButton)
        Theme.styleSecondaryButton(galleryButton)
        findButton.setTitle("Find Spots", for: .normal)
        Theme.adoptDynamicColors(in: view)
        titleLabel.textColor = Theme.ink
        greetingLabel.textColor = Theme.primary
        heroImageView.tintColor = Theme.primary
        lastSyncLabel.textColor = Theme.muted

        addSettingsButton()
        addChipRowAndAskButton()

        // The stack grew (chips + Ask), so let it scroll on small phones like the iPhone SE.
        if let stack = mainStack {
            Theme.embedInScrollView(stack, in: view, centered: true)
        }
    }

    /// Refresh every time we come back, because the nickname or sync time may have changed on later screens.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshGreeting()
        refreshLastSync()
    }

    /// Staggered fade/slide of every row the first time Home appears.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedIn, let stack = mainStack else { return }
        hasAnimatedIn = true
        for (index, row) in stack.arrangedSubviews.enumerated() {
            Theme.animateIn(row, delay: Double(index) * 0.05)
        }
    }

    // MARK: - Programmatic UI

    /// Gear in the top-right corner opens Settings (Gemini key, refresh, about).
    private func addSettingsButton() {
        let gear = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(settingsTapped))
        gear.accessibilityIdentifier = "settingsButton"
        gear.accessibilityLabel = "Settings"
        navigationItem.rightBarButtonItem = gear
    }

    /// Horizontal chips (🍜 Kain, ☕ Tambay, 🏋️ Galaw, 🎳 Gala) above Find Spots, and the
    /// "✨ Ask Kain Spot" button right below it.
    private func addChipRowAndAskButton() {
        guard let stack = mainStack else { return }

        let chipStack = UIStackView()
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        for kind in SpotKind.allCases {
            let chip = Theme.makeChip(title: "\(kind.emoji) \(kind.title)",
                                      identifier: "chip\(kind.title)")
            chip.accessibilityLabel = "\(kind.title): \(kind.subtitle)"
            chip.addAction(UIAction { [weak self] _ in
                self?.chipTapped(kind)
            }, for: .touchUpInside)
            chipStack.addArrangedSubview(chip)
        }

        chipScrollView.showsHorizontalScrollIndicator = false
        chipScrollView.translatesAutoresizingMaskIntoConstraints = false
        chipScrollView.clipsToBounds = false
        chipScrollView.addSubview(chipStack)
        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScrollView.frameLayoutGuide.heightAnchor),
            chipScrollView.heightAnchor.constraint(equalToConstant: 40)
        ])

        // Insert the chips just above Find Spots and Ask just below it.
        // Identity check (===) instead of firstIndex(of:) so the implicitly-unwrapped outlet is never force-unwrapped.
        if let findIndex = stack.arrangedSubviews.firstIndex(where: { $0 === findButton }) {
            stack.insertArrangedSubview(chipScrollView, at: findIndex)
            stack.insertArrangedSubview(askButton, at: findIndex + 2)
        } else {
            stack.addArrangedSubview(chipScrollView)
            stack.addArrangedSubview(askButton)
        }
        askButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        askButton.addTarget(self, action: #selector(askTapped), for: .touchUpInside)

        // Smaller hero art keeps everything above the fold on short phones.
        // (view.bounds is still the storyboard's design size in viewDidLoad, so ask the screen.)
        if UIScreen.main.bounds.height < 700 {
            heroImageView.constraints
                .filter { $0.firstAttribute == .height }
                .forEach { $0.constant = 72 }
        }
    }

    /// "Hi, foodie!" until the user saves a nickname, then "Hi, <nickname>!".
    private func refreshGreeting() {
        let nickname = UserPrefs.shared.nickname
        greetingLabel.text = nickname.isEmpty ? "Hi, foodie!" : "Hi, \(nickname)!"
    }

    /// Shows when the spot list was last downloaded, read from UserDefaults.
    private func refreshLastSync() {
        if let lastSync = UserPrefs.shared.lastSync {
            lastSyncLabel.text = "Last updated: \(syncDateFormatter.string(from: lastSync))"
        } else {
            lastSyncLabel.text = "Last updated: not yet — tap Find Spots"
        }
    }

    // MARK: - Actions (manual segues so the flow is explicit in code)

    @IBAction func findSpotsTapped(_ sender: UIButton) {
        Theme.hapticLight()
        performSegue(withIdentifier: "showPreferences", sender: self)
    }

    @IBAction func galleryTapped(_ sender: UIButton) {
        Theme.hapticLight()
        performSegue(withIdentifier: "showGallery", sender: self)
    }

    /// A chip jumps straight to "Plan your vacant" with that kind pre-selected.
    private func chipTapped(_ kind: SpotKind) {
        Theme.hapticLight()
        performSegue(withIdentifier: "showPreferences", sender: kind)
    }

    @objc private func askTapped() {
        Theme.hapticLight()
        navigationController?.pushViewController(AskViewController(), animated: true)
    }

    @objc private func settingsTapped() {
        Theme.hapticLight()
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    /// Passes the tapped chip's kind to Preferences (Week 2 data passing). Plain "Find Spots" passes nothing,
    /// so Preferences keeps whatever kind was saved last time.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard segue.identifier == "showPreferences",
              let dest = segue.destination as? PreferencesViewController,
              let kind = sender as? SpotKind else { return }
        dest.presetKind = kind
    }
}
