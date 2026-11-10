//
//  GalleryViewController.swift
//  KainSpot — Controller layer
//  "My Food Gallery": a 3-column grid of the user's own food photos saved in the app's Documents folder.
//  Course week: Week 7 (UICollectionView, multi-select PHPicker, reusable PhotoStore file persistence).
//  Feature: UI upgrade — tiles fade in on first appearance, friendlier animated empty state.
//

import UIKit
import PhotosUI

/// Grid of saved food photos with add (multi-select) and tap-to-delete.
final class GalleryViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var emptyLabel: UILabel!

    private let photoStore = PhotoStore.gallery
    private var fileNames: [String] = []
    /// How many picked items failed during the current import (main queue only).
    private var importFailures = 0

    /// Decoded thumbnails, so scrolling doesn't re-read full-size JPEGs from disk every time.
    private let thumbnailCache = NSCache<NSString, UIImage>()

    /// File names that already played their entrance animation (first appearance only).
    private var animatedFileNames = Set<String>()

    private let columns: CGFloat = 3
    private let spacing: CGFloat = 2

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Food Gallery"
        view.backgroundColor = Theme.background
        emptyLabel.textColor = Theme.muted
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.attributedText = emptyStateText()

        // Data source/delegate set in code (not the storyboard) so the wiring is easy to follow.
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = Theme.background

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumInteritemSpacing = spacing
            layout.minimumLineSpacing = spacing
            layout.sectionInset = .zero
            layout.estimatedItemSize = .zero // fixed square sizes, no self-sizing
        }

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        addButton.accessibilityLabel = "Add photos"
        addButton.accessibilityIdentifier = "addPhotoButton"
        navigationItem.rightBarButtonItem = addButton

        reloadPhotos()
    }

    /// Item size depends on the real width, which is only known after layout — so compute it here.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let width = collectionView.bounds.width
            - collectionView.adjustedContentInset.left
            - collectionView.adjustedContentInset.right
        guard width > 0 else { return }
        let side = floor((width - spacing * (columns - 1)) / columns)
        let newSize = CGSize(width: side, height: side)
        if layout.itemSize != newSize {
            layout.itemSize = newSize
            layout.invalidateLayout()
        }
    }

    // MARK: - Data

    /// Re-reads the folder (oldest first) and toggles the empty-state message.
    private func reloadPhotos() {
        fileNames = photoStore.allFileNames()
        collectionView.reloadData()
        let wasHidden = emptyLabel.isHidden
        emptyLabel.isHidden = !fileNames.isEmpty
        // Pop the empty state in (first load, or after deleting the last photo) so it feels alive.
        if !emptyLabel.isHidden && (wasHidden || !hasShownEmptyState) {
            hasShownEmptyState = true
            Theme.animateIn(emptyLabel, delay: 0.1)
        }
    }

    /// True once the empty-state entrance has played on this screen.
    private var hasShownEmptyState = false

    /// Big camera emoji, a bold headline and a muted hint, as one centred block.
    private func emptyStateText() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 6
        let text = NSMutableAttributedString(
            string: "📸\n",
            attributes: [.font: UIFont.systemFont(ofSize: 64), .paragraphStyle: paragraph])
        text.append(NSAttributedString(
            string: "No food pics yet\n",
            attributes: [.font: UIFont.systemFont(ofSize: 20, weight: .bold),
                         .foregroundColor: Theme.ink, .paragraphStyle: paragraph]))
        text.append(NSAttributedString(
            string: "Tap + to add your kain moments",
            attributes: [.font: UIFont.systemFont(ofSize: 16),
                         .foregroundColor: Theme.muted, .paragraphStyle: paragraph]))
        return text
    }

    /// Reads and shrinks a photo off the main thread, then hands it back on main.
    private func loadThumbnail(named name: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = thumbnailCache.object(forKey: name as NSString) {
            completion(cached)
            return
        }
        let store = photoStore
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let full = store.load(named: name)
            let thumb = full?.preparingThumbnail(of: CGSize(width: 400, height: 400)) ?? full
            DispatchQueue.main.async {
                if let thumb = thumb {
                    self?.thumbnailCache.setObject(thumb, forKey: name as NSString)
                }
                completion(thumb)
            }
        }
    }

    // MARK: - Actions

    /// Multi-select picker (selectionLimit 0 = unlimited).
    @objc private func addTapped() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 0
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// Confirms before deleting, because removing a file can't be undone.
    private func confirmDelete(at indexPath: IndexPath) {
        guard indexPath.item < fileNames.count else { return }
        let name = fileNames[indexPath.item]
        let alert = UIAlertController(title: "Delete this photo?",
                                      message: "It will be removed from your gallery.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deletePhoto(named: name)
        })
        present(alert, animated: true)
    }

    /// Saves one picked image (called on main); nil means the picker couldn't decode it.
    private func saveImported(_ image: UIImage?) {
        guard let image = image else {
            importFailures += 1
            return
        }
        do {
            _ = try photoStore.save(image)
        } catch {
            importFailures += 1
        }
    }

    private func deletePhoto(named name: String) {
        do {
            try photoStore.delete(named: name)
            thumbnailCache.removeObject(forKey: name as NSString)
            reloadPhotos()
        } catch {
            let alert = UIAlertController(title: "Couldn't delete photo",
                                          message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension GalleryViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        fileNames.count
    }

    /// Shows a placeholder immediately, then swaps in the thumbnail if the cell still shows the same file.
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as? GalleryCell,
              indexPath.item < fileNames.count else {
            return UICollectionViewCell()
        }
        let name = fileNames[indexPath.item]
        cell.representedFileName = name
        cell.configure(with: nil)
        cell.accessibilityLabel = "Food photo \(indexPath.item + 1)"
        loadThumbnail(named: name) { [weak cell] image in
            guard let cell = cell, cell.representedFileName == name else { return }
            cell.configure(with: image)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension GalleryViewController: UICollectionViewDelegate {

    /// Tiles fade and scale in the first time each photo shows up.
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard indexPath.item < fileNames.count else { return }
        let name = fileNames[indexPath.item]
        guard !animatedFileNames.contains(name) else { return }
        animatedFileNames.insert(name)
        cell.contentView.alpha = 0
        cell.contentView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(withDuration: 0.4, delay: min(Double(indexPath.item) * 0.03, 0.3),
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5,
                       options: [.allowUserInteraction]) {
            cell.contentView.alpha = 1
            cell.contentView.transform = .identity
        }
    }

    /// Tapping a photo offers to delete it.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        Theme.hapticLight()
        confirmDelete(at: indexPath)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension GalleryViewController: PHPickerViewControllerDelegate {

    /// Each selected item loads asynchronously; a DispatchGroup waits for all of them, and every
    /// save happens on the main queue so PhotoStore is never written from two threads at once.
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        let group = DispatchGroup()
        // Counted on the main queue only (instance property), so no captured var is mutated across threads.
        importFailures = 0

        for result in results {
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                importFailures += 1
                continue
            }
            group.enter()
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async {
                    defer { group.leave() }
                    self?.saveImported(image)
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.reloadPhotos()
            let failures = self.importFailures
            if failures > 0 {
                let alert = UIAlertController(title: "Some photos weren't added",
                                              message: "\(failures) photo(s) couldn't be loaded.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}
