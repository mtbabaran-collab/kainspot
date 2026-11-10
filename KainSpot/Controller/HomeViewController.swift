//
//  HomeViewController.swift
//  KainSpot — Controller layer
//  Welcome screen: logo, personalised greeting, and the two entry points (Find Food Spots / My Food Gallery).
//  Course week: Week 1 (Auto Layout with stack views, IBOutlets/IBActions) + Week 4 (reads UserDefaults).
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

    /// Human-friendly date for the "Last updated" line (e.g. "Nov 10, 2026 at 3:41 PM").
    private let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Applies the theme in code (corner radius, nav bar look) that the storyboard can't set.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        Theme.styleNavigationBar(navigationController?.navigationBar)
        Theme.stylePrimaryButton(findButton)
        Theme.styleSecondaryButton(galleryButton)
        titleLabel.textColor = Theme.ink
        greetingLabel.textColor = Theme.primary
        heroImageView.tintColor = Theme.primary
        lastSyncLabel.textColor = Theme.muted
    }

    /// Refresh every time we come back, because the nickname or sync time may have changed on later screens.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshGreeting()
        refreshLastSync()
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
            lastSyncLabel.text = "Last updated: not yet — tap Find Food Spots"
        }
    }

    // MARK: - Actions (manual segues so the flow is explicit in code)

    @IBAction func findSpotsTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showPreferences", sender: self)
    }

    @IBAction func galleryTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showGallery", sender: self)
    }
}
