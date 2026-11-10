//
//  PreferencesViewController.swift
//  KainSpot — Controller layer
//  "Plan your kain" form: nickname, budget, trending toggle and distance; builds a SpotFilter and passes it on.
//  Course week: Week 2 (input controls + passing data between view controllers with prepare(for:sender:)).
//

import UIKit

/// Collects the user's food preferences and hands a `SpotFilter` to the spot list.
final class PreferencesViewController: UIViewController {

    @IBOutlet weak var nicknameField: UITextField!
    @IBOutlet weak var priceSegment: UISegmentedControl!
    @IBOutlet weak var trendingSwitch: UISwitch!
    @IBOutlet weak var distanceSlider: UISlider!
    @IBOutlet weak var distanceValueLabel: UILabel!
    @IBOutlet weak var showSpotsButton: UIButton!

    /// Wires delegates, styles controls and pre-fills the form from the last saved preferences.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        nicknameField.delegate = self
        Theme.stylePrimaryButton(showSpotsButton)
        priceSegment.selectedSegmentTintColor = Theme.primary
        priceSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        trendingSwitch.onTintColor = Theme.accent
        distanceSlider.minimumTrackTintColor = Theme.primary

        prefill(with: UserPrefs.shared.loadFilter())

        // Tapping empty space hides the keyboard; cancelsTouchesInView = false keeps buttons/sliders working.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    /// Restores saved values, clamping them so a bad stored value can't put a control out of range.
    private func prefill(with filter: SpotFilter) {
        nicknameField.text = filter.nickname
        let lastSegment = max(priceSegment.numberOfSegments - 1, 0)
        priceSegment.selectedSegmentIndex = min(max(Int(filter.maxPrice), 0), lastSegment)
        trendingSwitch.isOn = filter.trendingOnly
        let km = Float(filter.maxDistanceKm)
        distanceSlider.value = min(max(km, distanceSlider.minimumValue), distanceSlider.maximumValue)
        updateDistanceLabel()
    }

    /// Whole kilometres read better than "4.37 km", so the label shows the rounded slider value.
    private func updateDistanceLabel() {
        distanceValueLabel.text = "Within \(Int(distanceSlider.value.rounded())) km"
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Actions

    @IBAction func distanceChanged(_ sender: UISlider) {
        updateDistanceLabel()
    }

    /// Validates the nickname, saves the preferences (Week 4) and moves on with the filter as the segue sender.
    @IBAction func showSpotsTapped(_ sender: UIButton) {
        let nickname = (nicknameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else {
            shake(nicknameField)
            let alert = UIAlertController(title: "Wait lang!",
                                          message: "Add a nickname so we know who's hungry 😋",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        view.endEditing(true)
        let filter = SpotFilter(nickname: nickname,
                                maxPrice: Int16(priceSegment.selectedSegmentIndex),
                                trendingOnly: trendingSwitch.isOn,
                                maxDistanceKm: Double(distanceSlider.value.rounded()))
        UserPrefs.shared.save(filter)
        performSegue(withIdentifier: "showSpotList", sender: filter)
    }

    /// A quick horizontal wiggle draws attention to the field that needs fixing.
    private func shake(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-10, 10, -8, 8, -5, 5, 0]
        view.layer.add(animation, forKey: "shake")
    }

    // MARK: - Navigation

    /// Passes the filter forward (Week 2: data passing between screens).
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard segue.identifier == "showSpotList",
              let dest = segue.destination as? SpotListViewController,
              let filter = sender as? SpotFilter else { return }
        dest.filter = filter
    }
}

// MARK: - UITextFieldDelegate

extension PreferencesViewController: UITextFieldDelegate {
    /// Return key closes the keyboard instead of inserting anything.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
