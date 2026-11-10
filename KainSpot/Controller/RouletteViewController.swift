//
//  RouletteViewController.swift
//  KainSpot — Controller layer
//  "Can't decide? Spin!" — a slot-machine style shuffle through the current results that slows down,
//  lands on one spot with a success haptic and confetti, then opens it.
//  Feature: Kain Roulette (programmatic UIKit, Auto Layout anchors, CAEmitterLayer, haptics).
//

import UIKit

/// Modal screen. The presenter supplies the candidates and handles "Let's go!" through `onLetsGo`,
/// because only the presenter owns the navigation controller that should show the detail screen.
final class RouletteViewController: UIViewController {

    /// Called after this screen is dismissed, with the spot the roulette landed on.
    var onLetsGo: ((Spot) -> Void)?

    private let candidates: [Spot]
    private var currentIndex = 0
    /// Bumped on every spin so ticks scheduled by an older spin quietly stop.
    private var spinToken = 0
    private var isSpinning = false

    private let titleLabel = UILabel()
    private let emojiLabel = UILabel()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let spinAgainButton = Theme.makeSecondaryButton(title: "🎰 Spin again", identifier: "spinAgainButton")
    private let letsGoButton = Theme.makePrimaryButton(title: "Let's go!", identifier: "letsGoButton")
    private var confettiLayer: CAEmitterLayer?

    init(candidates: [Spot]) {
        self.candidates = candidates
        super.init(nibName: nil, bundle: nil)
    }

    /// Storyboards never create this screen, so the coder init is unsupported (returns nil, no crash).
    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        view.accessibilityIdentifier = "rouletteScreen"
        buildLayout()
        currentIndex = candidates.isEmpty ? 0 : Int.random(in: 0..<candidates.count)
        showCandidate(at: currentIndex)
    }

    /// Start spinning as soon as the sheet is on screen — that's the fun part.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        spin()
    }

    /// Cancel pending ticks if the user swipes the sheet away mid-spin.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        spinToken += 1
    }

    // MARK: - Layout

    private func buildLayout() {
        titleLabel.text = "Can't decide? Spin! 🎰"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = Theme.ink
        titleLabel.textAlignment = .center

        emojiLabel.font = UIFont.systemFont(ofSize: 96)
        emojiLabel.textAlignment = .center
        emojiLabel.accessibilityIdentifier = "rouletteEmoji"

        nameLabel.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        nameLabel.textColor = Theme.ink
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7
        nameLabel.accessibilityIdentifier = "rouletteName"

        detailLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        detailLabel.textColor = Theme.muted
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 2

        let card = UIView()
        Theme.styleCard(card)
        let cardStack = UIStackView(arrangedSubviews: [emojiLabel, nameLabel, detailLabel])
        cardStack.axis = .vertical
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])

        spinAgainButton.addTarget(self, action: #selector(spinAgainTapped), for: .touchUpInside)
        letsGoButton.addTarget(self, action: #selector(letsGoTapped), for: .touchUpInside)

        let closeButton = UIButton(type: .close)
        closeButton.accessibilityIdentifier = "rouletteCloseButton"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, card, letsGoButton, spinAgainButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(28, after: card)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(closeButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: closeButton.bottomAnchor, constant: 8),
            letsGoButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            spinAgainButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])

        if candidates.isEmpty {
            emojiLabel.text = "🤷"
            nameLabel.text = "No spots to spin"
            detailLabel.text = "Try a longer vacant or a bigger budget."
            spinAgainButton.isEnabled = false
            letsGoButton.isEnabled = false
        }
    }

    /// Shows one candidate's emoji, name and kind/price line.
    private func showCandidate(at index: Int) {
        guard index >= 0, index < candidates.count else { return }
        let spot = candidates[index]
        emojiLabel.text = KainNavigator.emoji(for: spot)
        nameLabel.text = spot.name ?? "Mystery spot"
        let kind = KainNavigator.kind(of: spot)?.title ?? "Spot"
        detailLabel.text = "\(kind) · \(KainNavigator.priceText(for: spot)) · ★ \(String(format: "%.1f", spot.rating))"
    }

    // MARK: - Spin

    /// Ticks start fast and each delay grows by 12% until about 2.5 s have passed, like a slot reel
    /// slowing down. Each tick moves to the next candidate with a light selection haptic.
    private func spin() {
        guard candidates.count > 0, !isSpinning else { return }
        isSpinning = true
        spinToken += 1
        let token = spinToken
        removeConfetti()
        setButtons(enabled: false)

        var delays: [TimeInterval] = []
        var delay: TimeInterval = 0.04
        var total: TimeInterval = 0
        while total < 2.5 {
            delays.append(delay)
            total += delay
            delay *= 1.12
        }
        // A random number of extra steps makes the landing spot unpredictable even with few candidates.
        let jump = Int.random(in: 0..<max(candidates.count, 1))
        currentIndex = (currentIndex + jump) % candidates.count
        scheduleTick(remaining: delays[...], token: token)
    }

    /// Recursive scheduling keeps the decelerating rhythm without a repeating Timer.
    private func scheduleTick(remaining: ArraySlice<TimeInterval>, token: Int) {
        guard let next = remaining.first else {
            finishSpin()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + next) { [weak self] in
            guard let self = self, token == self.spinToken else { return }
            self.currentIndex = (self.currentIndex + 1) % max(self.candidates.count, 1)
            self.showCandidate(at: self.currentIndex)
            Theme.hapticSelection()
            // Quick squash so each tick feels physical.
            self.emojiLabel.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            UIView.animate(withDuration: 0.12) {
                self.emojiLabel.transform = .identity
            }
            self.scheduleTick(remaining: remaining.dropFirst(), token: token)
        }
    }

    /// Landing: success haptic, a bounce, and a burst of confetti.
    private func finishSpin() {
        isSpinning = false
        setButtons(enabled: true)
        Theme.hapticSuccess()
        emojiLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.4,
                       initialSpringVelocity: 6, options: [.allowUserInteraction]) {
            self.emojiLabel.transform = .identity
        }
        launchConfetti()
    }

    private func setButtons(enabled: Bool) {
        spinAgainButton.isEnabled = enabled
        letsGoButton.isEnabled = enabled
        letsGoButton.alpha = enabled ? 1 : 0.6
    }

    // MARK: - Confetti

    /// A short CAEmitterLayer burst from the top edge using small colored rectangles.
    private func launchConfetti() {
        removeConfetti()
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        let colors: [UIColor] = [Theme.primary, Theme.accent, .systemYellow, .systemPink, .systemPurple]
        emitter.emitterCells = colors.compactMap { makeConfettiCell(color: $0) }
        view.layer.addSublayer(emitter)
        confettiLayer = emitter

        // Stop emitting after a moment; let the pieces fall, then clean up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak emitter] in
            emitter?.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self, weak emitter] in
            guard let self = self, let emitter = emitter, emitter === self.confettiLayer else { return }
            self.removeConfetti()
        }
    }

    private func makeConfettiCell(color: UIColor) -> CAEmitterCell? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 6))
        let image = renderer.image { context in
            color.resolvedColor(with: traitCollection).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 6))
        }
        guard let cgImage = image.cgImage else { return nil }
        let cell = CAEmitterCell()
        cell.contents = cgImage
        cell.birthRate = 14
        cell.lifetime = 5
        cell.velocity = 220
        cell.velocityRange = 80
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 5
        cell.yAcceleration = 160
        cell.spin = 3
        cell.spinRange = 4
        cell.scale = 1
        cell.scaleRange = 0.4
        return cell
    }

    private func removeConfetti() {
        confettiLayer?.removeFromSuperlayer()
        confettiLayer = nil
    }

    // MARK: - Actions

    @objc private func spinAgainTapped() {
        Theme.hapticLight()
        spin()
    }

    /// Dismiss first, then let the presenter push the detail on its own navigation controller.
    @objc private func letsGoTapped() {
        guard !isSpinning, currentIndex < candidates.count else { return }
        let spot = candidates[currentIndex]
        let handler = onLetsGo
        Theme.hapticLight()
        dismiss(animated: true) {
            handler?(spot)
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
