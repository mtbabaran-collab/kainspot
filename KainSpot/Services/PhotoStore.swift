//
//  PhotoStore.swift
//  KainSpot
//
//  Reusable file-based photo storage used by BOTH the spot detail screen and the gallery (DRY).
//  Course week: Week 7 (MVC service layer, persisting user images in the Documents folder).
//

import Foundation
import UIKit

/// Errors that can happen while writing a photo.
enum PhotoStoreError: Error {
    case encodingFailed
}

/// Saves, loads, lists and deletes JPEG photos inside Documents/<folderName>.
/// Photos are files, not Core Data rows, so a sync that deletes and re-inserts spots never loses them.
final class PhotoStore {

    /// One photo per spot, named "spot-<id>.jpg".
    static let spotPhotos = PhotoStore(folderName: "SpotPhotos")
    /// The user's free-form food gallery.
    static let gallery = PhotoStore(folderName: "Gallery")

    private let folderName: String
    private let fileManager: FileManager
    private let baseURL: URL?

    /// - Parameters:
    ///   - folderName: sub-folder that keeps each feature's photos apart.
    ///   - baseURL: override for tests (a temp directory); nil means the app's Documents folder.
    init(folderName: String, fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.folderName = folderName
        self.fileManager = fileManager
        self.baseURL = baseURL
    }

    /// Resolves the folder and creates it lazily the first time it is needed.
    private func folderURL() throws -> URL {
        let base: URL
        if let baseURL = baseURL {
            base = baseURL
        } else {
            base = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
        return folder
    }

    /// Strips any path parts so a name can never escape the folder (e.g. "../x.jpg").
    private func safeName(_ name: String) -> String {
        (name as NSString).lastPathComponent
    }

    /// Writes the image as JPEG (quality 0.85 balances size and clarity) and returns the file name used.
    /// Passing the same name again overwrites, which is how "Change My Photo" replaces a spot photo.
    @discardableResult
    func save(_ image: UIImage, named name: String? = nil) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw PhotoStoreError.encodingFailed
        }
        let fileName = safeName(name ?? "\(UUID().uuidString).jpg")
        let url = try folderURL().appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    /// Returns the stored image, or nil if it does not exist or cannot be read.
    func load(named name: String) -> UIImage? {
        guard let folder = try? folderURL() else { return nil }
        let url = folder.appendingPathComponent(safeName(name))
        return UIImage(contentsOfFile: url.path)
    }

    /// All photo file names, oldest first, so the gallery grid keeps the order photos were added.
    /// Ties (same timestamp) fall back to name order to keep the result stable.
    func allFileNames() -> [String] {
        guard let folder = try? folderURL(),
              let urls = try? fileManager.contentsOfDirectory(at: folder,
                                                              includingPropertiesForKeys: [.creationDateKey],
                                                              options: [.skipsHiddenFiles]) else {
            return []
        }
        let dated: [(name: String, date: Date)] = urls.map { url in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return (url.lastPathComponent, date)
        }
        return dated
            .sorted { lhs, rhs in
                lhs.date == rhs.date ? lhs.name < rhs.name : lhs.date < rhs.date
            }
            .map { $0.name }
    }

    /// Removes a photo; deleting a file that is already gone is treated as success.
    func delete(named name: String) throws {
        let url = try folderURL().appendingPathComponent(safeName(name))
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    /// True when a photo with this name is on disk (used to switch "Add" / "Change My Photo").
    func exists(named name: String) -> Bool {
        guard let folder = try? folderURL() else { return false }
        return fileManager.fileExists(atPath: folder.appendingPathComponent(safeName(name)).path)
    }
}
