//
//  SpotCell.swift
//  KainSpot — View layer
//  Custom prototype table cell (reuse id "SpotCell") showing one food spot as a rounded card.
//  Course week: Week 3 (custom UITableViewCell) and Week 5 (Core Data `Spot` displayed in a list).
//

import UIKit

/// Card-style row for the spot list. Layout lives in Main.storyboard; this class only styles and fills it.
final class SpotCell: UITableViewCell {

    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var trendingBadge: UILabel!
    @IBOutlet weak var thumbImageView: UIImageView!

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
    }

    /// Cells are recycled, so clear the old spot's photo to avoid flashing the wrong image.
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
        trendingBadge.isHidden = true
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
}
