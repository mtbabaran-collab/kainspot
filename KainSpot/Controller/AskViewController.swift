//
//  AskViewController.swift
//  KainSpot — Controller layer
//  "Ask Kain Spot ✨": the student types their situation in plain Taglish ("1 hr vacant, ₱150, gutom") and
//  gets up to 3 picks. Offline SmartRanker always runs first; Gemini (when a key exists) only re-explains
//  and re-orders those same candidates, so the screen never breaks without internet.
//  Feature: AI assistant (programmatic UIKit, Auto Layout anchors, async networking with graceful fallback).
//

import UIKit

/// Remembers whether the last Gemini call worked, so the status pill can say "✨ Gemini AI" or
/// "📴 Offline smart picks". In memory only: a fresh launch optimistically assumes the key works.
enum KainAIStatus {
    static var lastCallSucceeded = true

    /// True when the next question will (probably) be answered by Gemini.
    static var isGeminiReady: Bool {
        KeychainStore.geminiKey != nil && lastCallSucceeded
    }
}

/// Pushed from Home. Built fully in code so no storyboard scene is needed.
final class AskViewController: UIViewController {

    private let statusPill = KainPaddedLabel()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let askSendButton = Theme.makePrimaryButton(title: "Ask ✨", identifier: "askSendButton")
    private let summaryLabel = UILabel()
    private let picksStack = UIStackView()
    private var pageStack = UIStackView()

    /// Kept while a request runs so the service isn't deallocated mid-call.
    private var gemini: GeminiService?
    /// Bumped on every question so a late answer from an older question is ignored.
    private var requestToken = 0
    private let syncService = SpotSyncService()

    private let suggestions = [
        "2 hrs vacant, ₱200, gutom",
        "Study spot with WiFi",
        "Gym after class",
        "Something fun under ₱300"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ask Kain Spot ✨"
        view.backgroundColor = Theme.background
        buildLayout()
        updateStatusPill()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A key may have been added or removed in Settings since last time.
        updateStatusPill()
    }

    // MARK: - Layout

    private func buildLayout() {
        pageStack = KainNavigator.makeScrollingPage(in: view, spacing: 14)

        statusPill.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        statusPill.layer.cornerRadius = 13
        statusPill.layer.cornerCurve = .continuous
        statusPill.clipsToBounds = true
        statusPill.accessibilityIdentifier = "aiStatusPill"
        // Keep the pill its natural width instead of stretching across the page.
        let pillRow = UIStackView(arrangedSubviews: [statusPill, UIView()])
        pillRow.axis = .horizontal

        let intro = UILabel()
        intro.text = "Tell me your vacant, budget and mood — I'll find where you can go and still make it back for class."
        intro.numberOfLines = 0
        intro.font = UIFont.systemFont(ofSize: 15)
        intro.textColor = Theme.muted

        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = Theme.ink
        textView.backgroundColor = Theme.card
        textView.layer.cornerRadius = Theme.cardCornerRadius
        textView.layer.cornerCurve = .continuous
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.accessibilityIdentifier = "askTextView"
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true

        placeholderLabel.text = "e.g. 2 hrs vacant, ₱200, gutom na ako 😋"
        placeholderLabel.font = UIFont.systemFont(ofSize: 17)
        placeholderLabel.textColor = Theme.muted
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isUserInteractionEnabled = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 15),
            placeholderLabel.widthAnchor.constraint(equalTo: textView.widthAnchor, constant: -30)
        ])

        // Suggestion chips scroll sideways so they never wrap awkwardly on small phones.
        let chipStack = UIStackView()
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        for (index, suggestion) in suggestions.enumerated() {
            let chip = Theme.makeChip(title: suggestion, identifier: "suggestion\(index)")
            chip.addAction(UIAction { [weak self] _ in
                self?.useSuggestion(suggestion)
            }, for: .touchUpInside)
            chipStack.addArrangedSubview(chip)
        }
        let chipScroll = UIScrollView()
        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(chipStack)
        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScroll.frameLayoutGuide.heightAnchor),
            chipScroll.heightAnchor.constraint(equalToConstant: 40)
        ])

        askSendButton.addTarget(self, action: #selector(askTapped), for: .touchUpInside)
        askSendButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        summaryLabel.numberOfLines = 0
        summaryLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        summaryLabel.textColor = Theme.ink
        summaryLabel.accessibilityIdentifier = "askSummary"
        summaryLabel.isHidden = true

        picksStack.axis = .vertical
        picksStack.spacing = 12

        [pillRow, intro, textView, chipScroll, askSendButton, summaryLabel, picksStack].forEach {
            pageStack.addArrangedSubview($0)
        }
        pageStack.setCustomSpacing(22, after: askSendButton)
    }

    /// "✨ Gemini AI" (teal) when a key exists and the last call worked, else "📴 Offline smart picks".
    private func updateStatusPill() {
        if KainAIStatus.isGeminiReady {
            statusPill.text = "✨ Gemini AI"
            statusPill.backgroundColor = Theme.accent
            statusPill.textColor = .white
        } else {
            statusPill.text = "📴 Offline smart picks"
            statusPill.backgroundColor = Theme.chip
            statusPill.textColor = Theme.ink
        }
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    /// Loading state: spinner inside the button, disabled while waiting.
    private func setLoading(_ loading: Bool) {
        var configuration = askSendButton.configuration
        configuration?.showsActivityIndicator = loading
        configuration?.title = loading ? "Thinking…" : "Ask ✨"
        askSendButton.configuration = configuration
        askSendButton.isEnabled = !loading
    }

    // MARK: - Actions

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    /// A suggestion fills the box (it doesn't send), so the student can tweak it first.
    private func useSuggestion(_ text: String) {
        Theme.hapticLight()
        textView.text = text
        updatePlaceholder()
    }

    /// Validates, then makes sure there are spots to rank (first launch may need a sync), then answers.
    @objc private func askTapped() {
        let question = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            useSuggestion(suggestions[0])
            return
        }
        view.endEditing(true)
        Theme.hapticLight()
        setLoading(true)
        requestToken += 1
        let token = requestToken

        let spots = KainNavigator.fetchAllSpots()
        if spots.isEmpty {
            // Nothing saved yet: sync (falls back to the bundled list offline), then try again.
            syncService.sync { [weak self] _ in
                guard let self = self, token == self.requestToken else { return }
                self.answer(question, spots: KainNavigator.fetchAllSpots(), token: token)
            }
        } else {
            answer(question, spots: spots, token: token)
        }
    }

    /// Offline ranking first; Gemini only if a key exists. Any Gemini failure shows the offline top 3.
    private func answer(_ question: String, spots: [Spot], token: Int) {
        let query = QueryParser.parse(question)
        let ranked = SmartRanker.rank(spots: spots, query: query, filter: nil,
                                      distanceFrom: DistanceCalculator.feuDiliman, now: Date())
        // The student's own vacant, if they typed one; otherwise one class hour.
        let vacant = query.vacantMinutes ?? KainNavigator.defaultVacantMinutes

        guard KeychainStore.geminiKey != nil, !ranked.isEmpty else {
            showOffline(ranked, vacant: vacant)
            return
        }

        let candidates = ranked.prefix(GeminiService.maxCandidates).map { GeminiCandidate(scored: $0) }
        let service = GeminiService()
        gemini = service
        service.ask(userText: question, candidates: Array(candidates)) { [weak self] result in
            guard let self = self, token == self.requestToken else { return }
            self.gemini = nil
            switch result {
            case .success(let reply):
                // Map ids back to our ranked spots; ids we don't know are ignored.
                let byID = Dictionary(ranked.map { ($0.spot.id ?? "", $0) }, uniquingKeysWith: { first, _ in first })
                let picks = reply.picks.compactMap { pick -> (ScoredSpot, String)? in
                    guard let scored = byID[pick.id] else { return nil }
                    return (scored, pick.reason)
                }
                if picks.isEmpty {
                    KainAIStatus.lastCallSucceeded = false
                    self.showOffline(ranked, vacant: vacant)
                } else {
                    KainAIStatus.lastCallSucceeded = true
                    let summary = reply.summary.isEmpty ? "Here's what I found for you 👇" : reply.summary
                    self.showResults(summary: summary, picks: picks, vacant: vacant)
                }
            case .failure(let error):
                print("Gemini failed, using offline picks: \(error)")
                KainAIStatus.lastCallSucceeded = false
                self.showOffline(ranked, vacant: vacant)
            }
        }
    }

    /// SmartRanker's top 3 with its own reasons.
    private func showOffline(_ ranked: [ScoredSpot], vacant: Int) {
        let top = ranked.prefix(3).map { scored -> (ScoredSpot, String) in
            let reasons = scored.reasons.filter { $0 != "Closed now" }.prefix(3)
            return (scored, reasons.isEmpty ? "Highly rated and close to campus" : reasons.joined(separator: " · "))
        }
        let summary = top.isEmpty
            ? "Wala akong mahanap 😅 Try a longer vacant or a bigger budget."
            : "Here are my smart picks for you 👇"
        showResults(summary: summary, picks: Array(top), vacant: vacant)
    }

    /// Renders the summary plus up to 3 tappable pick cards.
    private func showResults(summary: String, picks: [(ScoredSpot, String)], vacant: Int) {
        setLoading(false)
        updateStatusPill()
        Theme.hapticSuccess()
        summaryLabel.text = summary
        summaryLabel.isHidden = false
        picksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, pick) in picks.prefix(3).enumerated() {
            let card = makePickCard(spot: pick.0.spot, reason: pick.1, vacant: vacant, index: index)
            picksStack.addArrangedSubview(card)
            Theme.animateIn(card, delay: Double(index) * 0.08)
        }
        Theme.animateIn(summaryLabel)
    }

    /// One result card: emoji, name, reason and the leave-by line. Tapping opens the spot.
    private func makePickCard(spot: Spot, reason: String, vacant: Int, index: Int) -> UIView {
        let card = UIControl()
        Theme.styleCard(card)
        card.accessibilityIdentifier = "askPick\(index)"
        card.isAccessibilityElement = true
        card.accessibilityTraits = .button

        let emoji = UILabel()
        emoji.text = KainNavigator.emoji(for: spot)
        emoji.font = UIFont.systemFont(ofSize: 40)
        emoji.setContentHuggingPriority(.required, for: .horizontal)

        let name = UILabel()
        name.text = spot.name ?? "Spot"
        name.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        name.textColor = Theme.ink
        name.numberOfLines = 0

        let reasonLabel = UILabel()
        reasonLabel.text = reason
        reasonLabel.font = UIFont.systemFont(ofSize: 15)
        reasonLabel.textColor = Theme.muted
        reasonLabel.numberOfLines = 0

        let plan = KainNavigator.plan(for: spot, vacantMinutes: vacant)
        let leave = UILabel()
        leave.text = "\(KainNavigator.travelText(plan)) · \(KainNavigator.leaveText(plan))"
        leave.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        leave.textColor = plan.fits ? Theme.accent : Theme.muted

        let textStack = UIStackView(arrangedSubviews: [name, reasonLabel, leave])
        textStack.axis = .vertical
        textStack.spacing = 4
        let row = UIStackView(arrangedSubviews: [emoji, textStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        card.accessibilityLabel = "\(spot.name ?? "Spot"). \(reason). \(leave.text ?? "")"

        Theme.addSpringPress(to: card)
        card.addAction(UIAction { [weak self] _ in
            self?.open(spot, vacant: vacant)
        }, for: .touchUpInside)
        return card
    }

    private func open(_ spot: Spot, vacant: Int) {
        Theme.hapticLight()
        guard let detail = KainNavigator.makeDetail(for: spot, vacantMinutes: vacant) else { return }
        navigationController?.pushViewController(detail, animated: true)
    }
}

// MARK: - UITextViewDelegate

extension AskViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
    }
}
