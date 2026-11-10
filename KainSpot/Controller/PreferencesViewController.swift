//
//  PreferencesViewController.swift
//  KainSpot — Controller layer
//  "Plan your vacant" form: nickname, kind, vacant length, budget, price band, trending, WiFi, student
//  discount and distance; builds a SpotFilter and passes it on.
//  Course week: Week 2 (input controls + passing data between view controllers with prepare(for:sender:)).
//  Feature: Vacant Planner inputs (added in code into the storyboard stack).
//

import UIKit

/// Collects the user's preferences and hands a `SpotFilter` to the spot list.
final class PreferencesViewController: UIViewController {

    @IBOutlet weak var nicknameField: UITextField!
    @IBOutlet weak var priceSegment: UISegmentedControl!
    @IBOutlet weak var trendingSwitch: UISwitch!
    @IBOutlet weak var distanceSlider: UISlider!
    @IBOutlet weak var distanceValueLabel: UILabel!
    @IBOutlet weak var showSpotsButton: UIButton!

    /// Set by Home when the user tapped a category chip; wins over the saved kind.
    var presetKind: SpotKind?

    // MARK: Programmatic controls (Vacant Planner)

    /// Segment 0 = all kinds, then one segment per `SpotKind` in declaration order.
    private let kindSegment = UISegmentedControl(items: ["All"] + SpotKind.allCases.map { $0.title })
    private let vacantSlider = UISlider()
    private let vacantValueLabel = UILabel()
    private let budgetSlider = UISlider()
    private let budgetValueLabel = UILabel()
    private let wifiSwitch = UISwitch()
    private let discountSwitch = UISwitch()

    /// Slider steps: vacant moves in 15-minute blocks, budget in ₱50 steps.
    private let vacantStep: Float = 15
    private let budgetStep: Float = 50

    /// Wires delegates, styles controls, adds the new inputs and pre-fills from the last saved preferences.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Plan your vacant"
        view.backgroundColor = Theme.background
        nicknameField.delegate = self
        Theme.stylePrimaryButton(showSpotsButton)
        priceSegment.selectedSegmentTintColor = Theme.primary
        priceSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        trendingSwitch.onTintColor = Theme.accent
        distanceSlider.minimumTrackTintColor = Theme.primary
        Theme.adoptDynamicColors(in: view)

        addVacantPlannerControls()
        prefill(with: UserPrefs.shared.loadFilter())

        // More rows than fit an iPhone SE now, so the form scrolls.
        if let stack = showSpotsButton.superview as? UIStackView {
            stack.spacing = 12
            Theme.embedInScrollView(stack, in: view, centered: false)
        }

        // Tapping empty space hides the keyboard; cancelsTouchesInView = false keeps buttons/sliders working.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Programmatic controls

    /// Builds kind / vacant / budget / WiFi / discount rows and inserts them right after the nickname field,
    /// so the most important "vacant" questions come before the older price/trending/distance ones.
    private func addVacantPlannerControls() {
        guard let stack = showSpotsButton.superview as? UIStackView else { return }

        kindSegment.accessibilityIdentifier = "kindSegment"
        kindSegment.selectedSegmentTintColor = Theme.primary
        kindSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        kindSegment.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)

        configure(slider: vacantSlider, min: 30, max: 240, identifier: "vacantSlider")
        vacantSlider.addTarget(self, action: #selector(vacantChanged), for: .valueChanged)
        configure(slider: budgetSlider, min: 0, max: 1000, identifier: "budgetSlider")
        budgetSlider.addTarget(self, action: #selector(budgetChanged), for: .valueChanged)

        wifiSwitch.accessibilityIdentifier = "wifiSwitch"
        wifiSwitch.onTintColor = Theme.accent
        wifiSwitch.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
        discountSwitch.accessibilityIdentifier = "discountSwitch"
        discountSwitch.onTintColor = Theme.accent
        discountSwitch.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)

        let rows: [UIView] = [
            sectionLabel("What are you up for?"),
            kindSegment,
            valueRow(title: "Vacant time", valueLabel: vacantValueLabel),
            vacantSlider,
            valueRow(title: "Budget per person", valueLabel: budgetValueLabel),
            budgetSlider,
            switchRow(title: "WiFi 📶", toggle: wifiSwitch),
            switchRow(title: "Student discount 🏷️", toggle: discountSwitch)
        ]

        // Insert after the nickname field; fall back to just above Show Spots.
        // Identity checks (===) so the implicitly-unwrapped outlets are compared, never force-unwrapped.
        let anchorIndex = stack.arrangedSubviews.firstIndex(where: { $0 === nicknameField }).map { $0 + 1 }
            ?? stack.arrangedSubviews.firstIndex(where: { $0 === showSpotsButton })
            ?? stack.arrangedSubviews.count
        for (offset, row) in rows.enumerated() {
            stack.insertArrangedSubview(row, at: anchorIndex + offset)
        }
        // The existing "Budget" header above the ₱ segment now reads better as "Price range".
        for case let label as UILabel in stack.arrangedSubviews where label.text == "Budget" {
            label.text = "Price range"
        }
    }

    private func configure(slider: UISlider, min: Float, max: Float, identifier: String) {
        slider.minimumValue = min
        slider.maximumValue = max
        slider.minimumTrackTintColor = Theme.primary
        slider.accessibilityIdentifier = identifier
    }

    /// Grey semibold caption matching the storyboard's section labels.
    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = Theme.muted
        return label
    }

    /// "Vacant time ........ 60 min vacant" row.
    private func valueRow(title: String, valueLabel: UILabel) -> UIView {
        valueLabel.font = UIFont.boldSystemFont(ofSize: 15)
        valueLabel.textColor = Theme.primary
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [sectionLabel(title), valueLabel])
        row.axis = .horizontal
        row.spacing = 8
        return row
    }

    /// "WiFi 📶 ............ [switch]" row.
    private func switchRow(title: String, toggle: UISwitch) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = Theme.ink
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    // MARK: - Prefill

    /// Restores saved values, clamping them so a bad stored value can't put a control out of range.
    private func prefill(with filter: SpotFilter) {
        nicknameField.text = filter.nickname
        let lastSegment = max(priceSegment.numberOfSegments - 1, 0)
        priceSegment.selectedSegmentIndex = min(max(Int(filter.maxPrice), 0), lastSegment)
        trendingSwitch.isOn = filter.trendingOnly
        let km = Float(filter.maxDistanceKm)
        distanceSlider.value = min(max(km, distanceSlider.minimumValue), distanceSlider.maximumValue)
        updateDistanceLabel()

        // A chip tapped on Home beats the saved kind.
        let kind = presetKind ?? filter.kind.flatMap { SpotKind(rawValue: $0) }
        if let kind = kind, let index = SpotKind.allCases.firstIndex(of: kind) {
            kindSegment.selectedSegmentIndex = index + 1
        } else {
            kindSegment.selectedSegmentIndex = 0
        }

        let vacant = filter.vacantMinutes > 0 ? Float(filter.vacantMinutes) : 60
        vacantSlider.value = min(max(vacant, vacantSlider.minimumValue), vacantSlider.maximumValue)
        budgetSlider.value = min(max(Float(filter.maxSpend), budgetSlider.minimumValue), budgetSlider.maximumValue)
        wifiSwitch.isOn = filter.needsWifi
        discountSwitch.isOn = filter.studentDiscount
        updateVacantLabel()
        updateBudgetLabel()
    }

    /// Whole kilometres read better than "4.37 km", so the label shows the rounded slider value.
    private func updateDistanceLabel() {
        distanceValueLabel.text = "Within \(Int(distanceSlider.value.rounded())) km"
    }

    /// Snaps the vacant slider to 15-minute blocks: "60 min vacant", "1 hr 30 min vacant" is too long for a label.
    private func updateVacantLabel() {
        let snapped = (vacantSlider.value / vacantStep).rounded() * vacantStep
        vacantSlider.value = snapped
        vacantValueLabel.text = "\(Int(snapped)) min vacant"
    }

    /// Snaps the budget to ₱50 steps; 0 means "any budget".
    private func updateBudgetLabel() {
        let snapped = (budgetSlider.value / budgetStep).rounded() * budgetStep
        budgetSlider.value = snapped
        budgetValueLabel.text = snapped <= 0 ? "Any budget" : "Up to ₱\(Int(snapped))"
    }

    /// Currently selected kind raw value, or nil for "All".
    private var selectedKind: String? {
        let index = kindSegment.selectedSegmentIndex - 1
        guard index >= 0, index < SpotKind.allCases.count else { return nil }
        return SpotKind.allCases[index].rawValue
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Actions

    @IBAction func distanceChanged(_ sender: UISlider) {
        updateDistanceLabel()
    }

    @objc private func vacantChanged() {
        let before = vacantValueLabel.text
        updateVacantLabel()
        if vacantValueLabel.text != before { Theme.hapticSelection() }
    }

    @objc private func budgetChanged() {
        let before = budgetValueLabel.text
        updateBudgetLabel()
        if budgetValueLabel.text != before { Theme.hapticSelection() }
    }

    @objc private func selectionChanged() {
        Theme.hapticSelection()
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
        Theme.hapticLight()
        var filter = SpotFilter(nickname: nickname,
                                maxPrice: Int16(priceSegment.selectedSegmentIndex),
                                trendingOnly: trendingSwitch.isOn,
                                maxDistanceKm: Double(distanceSlider.value.rounded()))
        filter.kind = selectedKind
        filter.vacantMinutes = Int(vacantSlider.value)
        filter.maxSpend = Int(budgetSlider.value)
        filter.needsWifi = wifiSwitch.isOn
        filter.studentDiscount = discountSwitch.isOn
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
