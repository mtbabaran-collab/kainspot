//
//  UserPrefsTests.swift
//  KainSpotTests
//
//  Round-trip tests for UserPrefs using a private UserDefaults suite (never touches real settings).
//  Course week: Week 4 (UserDefaults) verified with XCTest.
//

import XCTest
@testable import KainSpot

final class UserPrefsTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults?

    /// A uniquely named suite keeps every test isolated from the app and from each other.
    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "KainSpotTests.UserPrefs.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        try super.tearDownWithError()
    }

    private func makePrefs() throws -> UserPrefs {
        let suite = try XCTUnwrap(defaults)
        return UserPrefs(defaults: suite)
    }

    /// Whatever filter is saved comes back unchanged.
    func testFilterRoundTrip() throws {
        let prefs = try makePrefs()
        let filter = SpotFilter(nickname: "Sis", maxPrice: 2, trendingOnly: true, maxDistanceKm: 7.5)

        prefs.save(filter)

        XCTAssertEqual(prefs.loadFilter(), filter)
        XCTAssertEqual(prefs.nickname, "Sis")
    }

    /// First launch (nothing saved) returns the default filter.
    func testEmptyDefaultsReturnDefaultFilter() throws {
        let prefs = try makePrefs()
        XCTAssertEqual(prefs.loadFilter(), SpotFilter.default)
        XCTAssertNil(prefs.lastSync)
    }

    /// lastSync stores a Date and can be cleared with nil.
    func testLastSyncRoundTrip() throws {
        let prefs = try makePrefs()
        let now = Date()

        prefs.lastSync = now
        let stored = try XCTUnwrap(prefs.lastSync)
        XCTAssertEqual(stored.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)

        prefs.lastSync = nil
        XCTAssertNil(prefs.lastSync)
    }

    /// Out-of-range stored price is clamped so the segmented control never gets a bad index.
    func testOutOfRangePriceIsClamped() throws {
        let prefs = try makePrefs()
        defaults?.set(9, forKey: UserPrefs.Key.maxPrice)
        XCTAssertEqual(prefs.loadFilter().maxPrice, 3)
    }

    /// The Vacant Planner choices survive a save/load round trip.
    func testVacantPlannerFieldsRoundTrip() throws {
        let prefs = try makePrefs()
        let filter = SpotFilter(nickname: "Sis", maxPrice: 0, trendingOnly: false, maxDistanceKm: 5,
                                kind: "galaw", maxSpend: 300, vacantMinutes: 90,
                                needsWifi: true, studentDiscount: true)
        prefs.save(filter)
        XCTAssertEqual(prefs.loadFilter(), filter)

        // Switching back to "all kinds" (nil) must clear the stored kind.
        var allKinds = filter
        allKinds.kind = nil
        prefs.save(allKinds)
        XCTAssertNil(prefs.loadFilter().kind)
    }

    /// Bad stored values fall back to safe defaults instead of breaking the planner.
    func testBadVacantPlannerValuesFallBack() throws {
        let prefs = try makePrefs()
        defaults?.set("swimming", forKey: UserPrefs.Key.kind)
        defaults?.set(-50, forKey: UserPrefs.Key.maxSpend)
        defaults?.set(0, forKey: UserPrefs.Key.vacantMinutes)
        let loaded = prefs.loadFilter()
        XCTAssertNil(loaded.kind)
        XCTAssertEqual(loaded.maxSpend, 0)
        XCTAssertEqual(loaded.vacantMinutes, 60)
    }
}
