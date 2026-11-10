//
//  SettingsViewController.swift
//  KainSpot — Controller layer
//  Settings: paste/save/remove the Gemini API key (stored in the Keychain, never in UserDefaults),
//  test the connection, refresh the places list now, and the About blurb.
//  Feature: AI assistant setup + manual sync (programmatic UIKit, Auto Layout anchors).
//

import UIKit

/// Pushed from the gear button on Home.
final class SettingsViewController: UIViewController {

    private let keyField = UITextField()
    private let keyStatusLabel = UILabel()
    private let saveButton = Theme.makePrimaryButton(title: "Save key", identifier: "saveKeyButton")
    private let removeButton = Theme.makeSecondaryButton(title: "Remove", identifier: "removeKeyButton")
    private let testButton = Theme.makeSecondaryButton(title: "Test connection", identifier: "testConnectionButton")
    private let testResultLabel = UILabel()
    private let refreshButton = Theme.makeSecondaryButton(title: "🔄 Refresh places now", identifier: "refreshPlacesButton")
    private let refreshResultLabel = UILabel()

    private let syncService = SpotSyncService()
    /// Kept alive while a test request runs.
    private var gemini: GeminiService?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = Theme.background
        buildLayout()
        refreshKeyStatus()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Layout

    private func buildLayout() {
        let page = KainNavigator.makeScrollingPage(in: view, spacing: 12)

        keyField.placeholder = "Gemini API key"
        keyField.isSecureTextEntry = true
        keyField.autocapitalizationType = .none
        keyField.autocorrectionType = .no
        keyField.borderStyle = .roundedRect
        keyField.backgroundColor = Theme.card
        keyField.textColor = Theme.ink
        keyField.returnKeyType = .done
        keyField.delegate = self
        keyField.accessibilityIdentifier = "geminiKeyField"
        keyField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        styleResult(keyStatusLabel)
        keyStatusLabel.accessibilityIdentifier = "keyStatusLabel"
        styleResult(testResultLabel)
        testResultLabel.accessibilityIdentifier = "testResultLabel"
        styleResult(refreshResultLabel)
        refreshResultLabel.accessibilityIdentifier = "refreshResultLabel"

        let keyButtons = UIStackView(arrangedSubviews: [saveButton, removeButton])
        keyButtons.axis = .horizontal
        keyButtons.spacing = 12
        keyButtons.distribution = .fillEqually

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        testButton.addTarget(self, action: #selector(testTapped), for: .touchUpInside)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        let about = UILabel()
        about.text = "Kain Spot v1.0 — made for FEU Diliman students 🎓\nPlan your vacant: kain, tambay, galaw, gala — and still be back for class."
        about.numberOfLines = 0
        about.font = UIFont.systemFont(ofSize: 15)
        about.textColor = Theme.ink
        about.accessibilityIdentifier = "aboutLabel"

        let keyHint = UILabel()
        keyHint.text = "Optional. Without a key, Ask Kain Spot still works with offline smart picks. "
            + "Your key stays in this phone's Keychain."
        keyHint.numberOfLines = 0
        keyHint.font = UIFont.systemFont(ofSize: 13)
        keyHint.textColor = Theme.muted

        let views: [UIView] = [
            header("✨ Gemini AI"), keyHint, keyField, keyButtons, keyStatusLabel,
            testButton, testResultLabel,
            header("📍 Places"), refreshButton, refreshResultLabel,
            header("ℹ️ About"), about
        ]
        views.forEach { page.addArrangedSubview($0) }
        page.setCustomSpacing(24, after: testResultLabel)
        page.setCustomSpacing(24, after: refreshResultLabel)
    }

    private func header(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = Theme.ink
        return label
    }

    private func styleResult(_ label: UILabel) {
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = Theme.muted
    }

    /// Never shows the key itself — only whether one is saved.
    private func refreshKeyStatus() {
        if KeychainStore.geminiKey != nil {
            keyStatusLabel.text = "🔐 A key is saved. Ask Kain Spot will use Gemini."
            keyStatusLabel.textColor = Theme.accent
        } else {
            keyStatusLabel.text = "No key yet — using offline smart picks."
            keyStatusLabel.textColor = Theme.muted
        }
    }

    // MARK: - Actions

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    /// Saves a trimmed key to the Keychain and clears the field so it isn't left on screen.
    @objc private func saveTapped() {
        let key = (keyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            keyStatusLabel.text = "Paste your Gemini API key first."
            keyStatusLabel.textColor = Theme.primaryDark
            return
        }
        view.endEditing(true)
        if KeychainStore.save(key, for: KeychainStore.geminiAccount) {
            keyField.text = nil
            KainAIStatus.lastCallSucceeded = true
            Theme.hapticSuccess()
            refreshKeyStatus()
        } else {
            keyStatusLabel.text = "Couldn't save the key. Please try again."
            keyStatusLabel.textColor = Theme.primaryDark
        }
    }

    @objc private func removeTapped() {
        Theme.hapticLight()
        KeychainStore.delete(KeychainStore.geminiAccount)
        keyField.text = nil
        testResultLabel.text = nil
        refreshKeyStatus()
    }

    /// Sends a tiny real request using the top few saved spots as candidates.
    @objc private func testTapped() {
        Theme.hapticLight()
        guard KeychainStore.geminiKey != nil else {
            testResultLabel.text = "Add a key first, then test."
            testResultLabel.textColor = Theme.muted
            return
        }
        testResultLabel.text = "Testing…"
        testResultLabel.textColor = Theme.muted
        testButton.isEnabled = false

        let ranked = SmartRanker.rank(spots: KainNavigator.fetchAllSpots(), query: QueryParser.parse(""),
                                      filter: nil, distanceFrom: DistanceCalculator.feuDiliman, now: Date())
        let candidates = ranked.prefix(3).map { GeminiCandidate(scored: $0) }
        let service = GeminiService()
        gemini = service
        service.ask(userText: "Quick hello test: pick one spot.", candidates: Array(candidates)) { [weak self] result in
            guard let self = self else { return }
            self.gemini = nil
            self.testButton.isEnabled = true
            switch result {
            case .success:
                KainAIStatus.lastCallSucceeded = true
                self.testResultLabel.text = "✅ Connected! Gemini is ready."
                self.testResultLabel.textColor = Theme.success
                Theme.hapticSuccess()
            case .failure(let error):
                KainAIStatus.lastCallSucceeded = false
                self.testResultLabel.text = "❌ Couldn't connect (\(self.describe(error))). Offline smart picks still work."
                self.testResultLabel.textColor = Theme.primaryDark
            }
        }
    }

    /// Short, friendly error text (never includes the key).
    private func describe(_ error: Error) -> String {
        if let geminiError = error as? GeminiError {
            switch geminiError {
            case .noKey: return "no key"
            case .badStatus(let code): return code == 400 || code == 403 ? "key rejected" : "server said \(code)"
            case .allModelsUnavailable: return "models busy"
            default: return "unexpected reply"
            }
        }
        return "no internet?"
    }

    /// Manual sync; the service falls back to saved/bundled places when offline.
    @objc private func refreshTapped() {
        Theme.hapticLight()
        refreshButton.isEnabled = false
        refreshResultLabel.text = "Refreshing…"
        refreshResultLabel.textColor = Theme.muted
        syncService.sync { [weak self] result in
            guard let self = self else { return }
            self.refreshButton.isEnabled = true
            switch result {
            case .success(let count):
                self.refreshResultLabel.text = "✅ Updated \(count) places"
                self.refreshResultLabel.textColor = Theme.success
                Theme.hapticSuccess()
            case .failure:
                let saved = KainNavigator.fetchAllSpots().count
                self.refreshResultLabel.text = "📴 Offline — kept \(saved) saved places"
                self.refreshResultLabel.textColor = Theme.muted
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension SettingsViewController: UITextFieldDelegate {
    /// Return saves, which is what people expect after pasting a key.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveTapped()
        return true
    }
}
