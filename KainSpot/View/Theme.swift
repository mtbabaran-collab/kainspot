//
//  Theme.swift
//  KainSpot — View layer
//  Central color palette + styling helpers so every screen looks consistent (DRY).
//  Course week: Week 1 (UI design / Auto Layout look) and Week 7 (MVC — View helpers kept out of controllers).
//

import UIKit

/// App-wide colors and reusable styling. Colors are plain UIColor values (no asset catalog)
/// so they can be read directly in code and in unit tests.
enum Theme {

    // MARK: - Palette

    static let primary = Theme.color(hex: 0xFF6B35)      // warm orange
    static let primaryDark = Theme.color(hex: 0xE0521D)
    static let accent = Theme.color(hex: 0x2EC4B6)       // teal, "trending" badge
    static let ink = Theme.color(hex: 0x1F2933)          // main text
    static let muted = Theme.color(hex: 0x6B7280)        // secondary text
    static let background = Theme.color(hex: 0xFFF8F2)   // warm off-white screens
    static let card = Theme.color(hex: 0xFFFFFF)

    // MARK: - Metrics

    static let buttonCornerRadius: CGFloat = 14
    static let cardCornerRadius: CGFloat = 16

    // MARK: - Helpers

    /// Converts a 0xRRGGBB literal into a UIColor so the palette reads like the design spec.
    private static func color(hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Filled orange call-to-action button (main action on a screen).
    static func stylePrimaryButton(_ button: UIButton) {
        button.backgroundColor = primary
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .highlighted)
        button.layer.cornerRadius = buttonCornerRadius
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
    }

    /// White button with an orange outline for secondary actions.
    static func styleSecondaryButton(_ button: UIButton) {
        button.backgroundColor = card
        button.setTitleColor(primary, for: .normal)
        button.setTitleColor(primaryDark, for: .highlighted)
        button.layer.cornerRadius = buttonCornerRadius
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 2
        button.layer.borderColor = primary.cgColor
        button.clipsToBounds = true
    }

    /// Rounded white card with a soft shadow. masksToBounds stays false so the shadow is visible.
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
}
