//
//  SpotCell.swift
//  KainSpot — View layer
//  Custom prototype table cell (reuse id "SpotCell") showing one spot as a rounded card.
//  Course week: Week 3 (custom UITableViewCell) and Week 5 (Core Data `Spot` displayed in a list).
//  Feature: Vacant Planner line ("🚶 8 min" + "Leave by 2:40 PM") and pulsing 🔥 badge.
//

import UIKit

/// Card-style row for the spot list. Layout lives in Main.storyboard; this class styles and fills it,
/// and adds one extra label in code for the leave-by line.
final class SpotCell: UITableViewCell {

    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var trendingBadge: UILabel!
    @IBOutlet weak var thumbImageView: UIImageView!

    /// "Leave by 2:40 PM" (teal) or "Too far for this vacant" (muted). Added under the price row.
    private let leaveByLabel = UILabel()

    /// One-time styling (corner radius, shadow) that Interface Builder can't express.
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        Theme.styleCard(cardView)
        Theme.styleBadge(trendingBadge)
        thumbImageView.layer.cornerRadius = 12
        thumbImageView.layer.cornerCurve = .continuous
        thumbImageView.clipsToBounds = true
        thumbImageView.backgroundColor = Theme.background
        nameLabel.textColor = Theme.ink
        categoryLabel.textColor = Theme.muted
        priceLabel.textColor = Theme.primary
        distanceLabel.textColor = Theme.ink

        // The name/category/price column is a vertical stack in the storyboard; append our line to it.
        leaveByLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        leaveByLabel.textColor = Theme.accent
        if let column = nameLabel.superview as? UIStackView {
            column.spacing = 3
            column.addArrangedSubview(leaveByLabel)
        }
    }

    /// Cells are recycled, so clear the old spot's photo to avoid flashing the wrong image.
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
        trendingBadge.isHidden = true
        Theme.stopPulse(trendingBadge)
        leaveByLabel.text = nil
        contentView.alpha = 1
        contentView.transform = .identity
    }

    /// Fills the card from a Core Data `Spot`. The distance text and photo are computed by the
    /// controller so the cell stays a "dumb" view (MVC).
    func configure(with spot: Spot, distanceText: String, photo: UIImage?) {
        nameLabel.text = spot.name ?? "Unnamed spot"
        categoryLabel.text = spot.category ?? ""
        let price = PriceLevel(rawValue: spot.priceLevel)
        priceLabel.text = price?.symbol ?? "₱"
        distanceLabel.text = "\(distanceText) · ★ \(String(format: "%.1f", spot.rating))"

        // Padding spaces give the pill label some breathing room without a custom subclass.
        trendingBadge.text = "  🔥 Trending  "
        trendingBadge.isHidden = !spot.isTrending
        if spot.isTrending {
            Theme.pulse(trendingBadge)
        }

        if let photo = photo {
            thumbImageView.contentMode = .scaleAspectFill
            thumbImageView.image = photo
        } else {
            // No user photo yet: fall back to the SF Symbol placeholder.
            thumbImageView.contentMode = .center
            thumbImageView.image = UIImage(systemName: "fork.knife")
            thumbImageView.tintColor = Theme.primary
        }

        accessibilityLabel = "\(nameLabel.text ?? ""), \(categoryLabel.text ?? ""), \(distanceText)"
    }

    /// Vacant Planner version used by the upgraded list: emoji + name, kind/price, travel time and leave-by.
    func configure(with spot: Spot, plan: VacantPlan, photo: UIImage?) {
        configure(with: spot, distanceText: KainNavigator.travelText(plan), photo: photo)
        let emoji = KainNavigator.emoji(for: spot)
        nameLabel.text = "\(emoji) \(spot.name ?? "Unnamed spot")"
        let kindTitle = KainNavigator.kind(of: spot)?.title ?? "Spot"
        let category = spot.category ?? ""
        categoryLabel.text = category.isEmpty ? kindTitle : "\(kindTitle) · \(category)"
        priceLabel.text = KainNavigator.priceText(for: spot)
        leaveByLabel.text = KainNavigator.leaveText(plan)
        leaveByLabel.textColor = plan.fits ? Theme.accent : Theme.muted

        // Without a user photo, the big emoji makes a friendlier thumbnail than a fork icon.
        if photo == nil {
            thumbImageView.image = emojiImage(emoji)
            thumbImageView.contentMode = .center
        }
        accessibilityLabel = "\(spot.name ?? ""), \(kindTitle), \(KainNavigator.travelText(plan)), \(leaveByLabel.text ?? "")"
    }

    /// Renders an emoji into a 40pt image for the thumbnail slot.
    private func emojiImage(_ emoji: String) -> UIImage {
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let text = emoji as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34)]
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2)
            text.draw(at: origin, withAttributes: attributes)
        }
    }
}
