//
//  GalleryCell.swift
//  KainSpot — View layer
//  Square collection view cell (reuse id "GalleryCell") showing one saved food photo.
//  Course week: Week 7 (UICollectionView + file-based photo persistence).
//

import UIKit

/// One tile of the 3-column food gallery grid.
final class GalleryCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!

    /// File name currently shown. Images load off the main thread, so the controller checks this
    /// before assigning to avoid putting a late-arriving image into a recycled cell.
    var representedFileName: String?

    /// Aspect-fill + clipping makes every photo a clean square tile.
    override func awakeFromNib() {
        super.awakeFromNib()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = Theme.card
        contentView.clipsToBounds = true
    }

    /// Clears the recycled cell so an old photo never shows under a new file name.
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        representedFileName = nil
    }

    /// Shows the photo, or a neutral placeholder while it is still loading.
    func configure(with image: UIImage?) {
        if let image = image {
            imageView.contentMode = .scaleAspectFill
            imageView.image = image
        } else {
            imageView.contentMode = .center
            imageView.tintColor = Theme.muted
            imageView.image = UIImage(systemName: "photo")
        }
    }
}
