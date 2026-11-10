//
//  Theme.swift
//  KainSpot — View layer
//  Central color palette + styling, motion and haptic helpers so every screen looks and feels consistent (DRY).
//  Course week: Week 1 (UI design / Auto Layout look), Week 7 (MVC — View helpers kept out of controllers),
//  Feature: Dark Mode (dynamic colors), spring presses, pulse badge, haptics.
//

import UIKit

/// App-wide colors and reusable styling. Colors are plain UIColor values (no asset catalog)
/// so they can be read directly in code and in unit tests. Every color is *dynamic*: UIKit asks the
/// closure again whenever the light/dark appearance changes, so screens re-color themselves for free.
enum Theme {

    // MARK: - Palette (light value, dark value)

    static let primary = Theme.dynamic(light: 0xFF6B35, dark: 0xFF7A4A)      // warm orange
    static let primaryDark = Theme.dynamic(light: 0xE0521D, dark: 0xE8642F)
    static let accent = Theme.dynamic(light: 0x2EC4B6, dark: 0x3DD6C8)       // teal, "trending" + "leave by"
    static let ink = Theme.dynamic(light: 0x1F2933, dark: 0xF3F4F6)          // main text
    static let muted = Theme.dynamic(light: 0x6B7280, dark: 0x9CA3AF)        // secondary text
    static let background = Theme.dynamic(light: 0xFFF8F2, dark: 0x121212)   // screens
    static let card = Theme.dynamic(light: 0xFFFFFF, dark: 0x1E1E1E)         // cards, inputs
    static let chip = Theme.dynamic(light: 0xFFEBDD, dark: 0x2A2A2A)         // pill backgrounds
    static let success = Theme.dynamic(light: 0x16A34A, dark: 0x4ADE80)      // FEU Diliman pin, "connected"

    // MARK: - Metrics

    static let buttonCornerRadius: CGFloat = 14
    static let cardCornerRadius: CGFloat = 16

    // MARK: - Color helpers

    /// Converts a 0xRRGGBB literal into a UIColor so the palette reads like the design spec.
    private static func color(hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// A color that picks its light or dark value from the current trait collection.
    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        let lightColor = color(hex: light)
        let darkColor = color(hex: dark)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        }
    }

    // MARK: - Component styles

    /// Filled orange call-to-action button (main action on a screen).
    static func stylePrimaryButton(_ button: UIButton) {
        button.backgroundColor = primary
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .highlighted)
        button.layer.cornerRadius = buttonCornerRadius
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        addSpringPress(to: button)
    }

    /// Card-colored button with an orange outline for secondary actions.
    static func styleSecondaryButton(_ button: UIButton) {
        button.backgroundColor = card
        button.setTitleColor(primary, for: .normal)
        button.setTitleColor(primaryDark, for: .highlighted)
        button.layer.cornerRadius = buttonCornerRadius
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 2
        // CGColor is not dynamic; the orange is close enough in both modes to resolve it once.
        button.layer.borderColor = primary.resolvedColor(with: button.traitCollection).cgColor
        button.clipsToBounds = true
        addSpringPress(to: button)
    }

    /// Rounded card with a soft shadow. masksToBounds stays false so the shadow is visible.
    static func styleCard(_ view: UIView) {
        view.backgroundColor = card
        view.layer.cornerRadius = cardCornerRadius
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowRadius = 8
        view.layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    /// Small pill-shaped teal label used for the "Trending" badge.
    static func styleBadge(_ label: UILabel) {
        label.backgroundColor = accent
        label.textColor = .white
        label.layer.cornerRadius = 11
        label.clipsToBounds = true
    }

    /// Orange tint, solid bar, no large titles — applied once from the root screen.
    static func styleNavigationBar(_ navigationBar: UINavigationBar?) {
        guard let navigationBar = navigationBar else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.titleTextAttributes = [
            .foregroundColor: ink,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        appearance.shadowColor = .clear
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = primary
        navigationBar.prefersLargeTitles = false
    }

    /// Big filled call-to-action built in code (Ask, Spin, Save…), matching the storyboard primary buttons.
    static func makePrimaryButton(title: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = primary
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        addSpringPress(to: button)
        return button
    }

    /// Outlined secondary button built in code.
    static func makeSecondaryButton(title: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = title
        configuration.baseBackgroundColor = card
        configuration.baseForegroundColor = primary
        configuration.cornerStyle = .large
        configuration.background.strokeColor = primary
        configuration.background.strokeWidth = 2
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        addSpringPress(to: button)
        return button
    }

    /// Rounded "pill" button used for category chips and Ask suggestions (built in code).
    static func makeChip(title: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = chip
        configuration.baseForegroundColor = ink
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        addSpringPress(to: button)
        return button
    }

    /// Small non-interactive pill label (amenities on the detail screen, status on Ask).
    static func makePillLabel(_ text: String) -> UILabel {
        let label = KainPaddedLabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = ink
        label.backgroundColor = chip
        label.layer.cornerRadius = 13
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        return label
    }

    /// Storyboard labels/fields use fixed sRGB colors; this swaps the common ones for dynamic tokens
    /// so screens built before Dark Mode stay readable on a #121212 background.
    static func adoptDynamicColors(in root: UIView) {
        for subview in root.subviews {
            if let label = subview as? UILabel {
                if let replacement = dynamicEquivalent(of: label.textColor) {
                    label.textColor = replacement
                }
            } else if let field = subview as? UITextField {
                field.backgroundColor = card
                field.textColor = ink
            }
            adoptDynamicColors(in: subview)
        }
    }

    /// Maps a fixed palette color (ink / muted / orange) to its dynamic version, or nil if unknown.
    private static func dynamicEquivalent(of color: UIColor?) -> UIColor? {
        guard let color = color else { return nil }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func near(_ hex: UInt32) -> Bool {
            let r = CGFloat((hex >> 16) & 0xFF) / 255
            let g = CGFloat((hex >> 8) & 0xFF) / 255
            let b = CGFloat(hex & 0xFF) / 255
            return abs(r - red) < 0.03 && abs(g - green) < 0.03 && abs(b - blue) < 0.03
        }
        if near(0x1F2933) { return ink }
        if near(0x6B7280) { return muted }
        if near(0xFF6B35) { return primary }
        return nil
    }

    // MARK: - Layout helper

    /// Moves a storyboard stack view into a new scroll view so screens that grew (Home chips,
    /// Preferences "Plan your vacant") still fit an iPhone SE. Removing the stack from its old
    /// superview drops the storyboard constraints that pinned it; the stack's own subviews,
    /// outlets and actions are untouched.
    /// - Parameter centered: true keeps the stack vertically centred when there is spare room (Home).
    @discardableResult
    static func embedInScrollView(_ stack: UIView, in container: UIView,
                                  centered: Bool, horizontalInset: CGFloat = 24,
                                  verticalInset: CGFloat = 24) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.backgroundColor = .clear

        stack.removeFromSuperview()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)
        scrollView.addSubview(stack)

        let safe = container.safeAreaLayoutGuide
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        var constraints = [
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: horizontalInset),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -horizontalInset)
        ]
        if centered {
            // Content is at least one screen tall; the stack sits in its middle and the
            // content grows (low-priority equality loses) only when the stack needs more room.
            let fillScreen = content.heightAnchor.constraint(equalTo: frame.heightAnchor)
            fillScreen.priority = .defaultLow
            constraints += [
                content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
                fillScreen,
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                stack.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 16)
            ]
        } else {
            constraints += [
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: verticalInset),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -verticalInset)
            ]
        }
        NSLayoutConstraint.activate(constraints)
        return scrollView
    }

    // MARK: - Motion

    /// Scales a control to 0.96 while the finger is down and springs it back on release.
    /// Uses UIAction (iOS 14+) so no extra target object has to be kept alive.
    static func addSpringPress(to control: UIControl) {
        control.addAction(UIAction { [weak control] _ in
            UIView.animate(withDuration: 0.12, delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                control?.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            }
        }, for: [.touchDown, .touchDragEnter])
        control.addAction(UIAction { [weak control] _ in
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.45,
                           initialSpringVelocity: 4,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                control?.transform = .identity
            }
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    /// Gentle endless "breathing" for the 🔥 Trending badge. Safe to call repeatedly (added once).
    static func pulse(_ view: UIView) {
        let key = "kainPulse"
        guard view.layer.animation(forKey: key) == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.08
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        view.layer.add(animation, forKey: key)
    }

    /// Stops the pulse (used when a recycled cell no longer shows a trending spot).
    static func stopPulse(_ view: UIView) {
        view.layer.removeAnimation(forKey: "kainPulse")
    }

    /// Fade + slide-up entrance; `delay` lets callers stagger several views.
    static func animateIn(_ view: UIView, delay: TimeInterval = 0, offset: CGFloat = 18) {
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: offset)
        UIView.animate(withDuration: 0.5, delay: delay, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
            view.alpha = 1
            view.transform = .identity
        }
    }

    // MARK: - Haptics

    /// Light tap for button presses and chip taps.
    static func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Tick used by the roulette while it cycles through spots.
    static func hapticSelection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Celebration when the roulette lands or an answer arrives.
    static func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// UILabel with inner padding so pill labels don't hug their text. Prefixed "Kain" to avoid name clashes.
final class KainPaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    /// Grow the intrinsic size by the padding so Auto Layout gives the text room.
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
