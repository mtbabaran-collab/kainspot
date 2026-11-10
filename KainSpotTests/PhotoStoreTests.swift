//
//  PhotoStoreTests.swift
//  KainSpotTests
//
//  Round-trip tests for the shared PhotoStore, isolated in a temporary directory.
//  Course week: Week 7 (reusable persistence service) verified with XCTest.
//

import UIKit
import XCTest
@testable import KainSpot

final class PhotoStoreTests: XCTestCase {

    private var tempDirectory: URL?

    /// Each test gets a fresh temp folder so it never touches the app's real Documents photos.
    override func setUpWithError() throws {
        try super.setUpWithError()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        tempDirectory = url
    }

    override func tearDownWithError() throws {
        if let url = tempDirectory {
            try? FileManager.default.removeItem(at: url)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    /// Builds a tiny solid-color image in memory; no asset files needed.
    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    private func makeStore() throws -> PhotoStore {
        let base = try XCTUnwrap(tempDirectory)
        return PhotoStore(folderName: "TestPhotos", baseURL: base)
    }

    /// save -> exists -> load -> delete -> gone: the full life of a spot photo.
    func testSaveLoadDeleteRoundTrip() throws {
        let store = try makeStore()
        let name = try store.save(makeImage(), named: "spot-test.jpg")

        XCTAssertEqual(name, "spot-test.jpg")
        XCTAssertTrue(store.exists(named: name))
        XCTAssertNotNil(store.load(named: name))

        try store.delete(named: name)
        XCTAssertFalse(store.exists(named: name))
        XCTAssertNil(store.load(named: name))
    }

    /// Without a name the store invents a unique .jpg name (used by the gallery).
    func testSaveWithoutNameGeneratesJPGName() throws {
        let store = try makeStore()
        let first = try store.save(makeImage())
        let second = try store.save(makeImage())

        XCTAssertTrue(first.hasSuffix(".jpg"))
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(Set(store.allFileNames()), Set([first, second]))
    }

    /// An empty or fresh folder lists nothing instead of failing.
    func testEmptyStoreListsNothing() throws {
        let store = try makeStore()
        XCTAssertEqual(store.allFileNames(), [])
        XCTAssertFalse(store.exists(named: "missing.jpg"))
    }
}
