//
//  SharedUserDefaultsTests.swift
//  NetBirdTests
//

import XCTest
@testable import NetBird

final class SharedUserDefaultsTests: XCTestCase {

    var userDefaults: UserDefaults?

    override func setUpWithError() throws {
        try super.setUpWithError()
        userDefaults = UserDefaults(suiteName: GlobalConstants.userPreferencesSuiteName)
        guard userDefaults != nil else {
            throw XCTSkip("Shared UserDefaults suite not available (app group may not be configured)")
        }
    }

    override func tearDown() {
        userDefaults?.removeObject(forKey: GlobalConstants.keyLoginRequired)
        userDefaults?.removeObject(forKey: GlobalConstants.keyForceRelayConnection)
        super.tearDown()
    }

    func testUserDefaultsSuiteExists() throws {
        let defaults = try XCTUnwrap(userDefaults, "Shared UserDefaults suite should exist")
        XCTAssertNotNil(defaults)
    }

    func testLoginRequiredFlagDefaultsToFalse() throws {
        let defaults = try XCTUnwrap(userDefaults)
        defaults.removeObject(forKey: GlobalConstants.keyLoginRequired)
        let value = defaults.bool(forKey: GlobalConstants.keyLoginRequired)
        XCTAssertFalse(value, "Login required flag should default to false")
    }

    func testLoginRequiredFlagCanBeSet() throws {
        let defaults = try XCTUnwrap(userDefaults)
        defaults.set(true, forKey: GlobalConstants.keyLoginRequired)
        let value = defaults.bool(forKey: GlobalConstants.keyLoginRequired)
        XCTAssertTrue(value, "Login required flag should be true after setting")
    }

    func testLoginRequiredFlagCanBeCleared() throws {
        let defaults = try XCTUnwrap(userDefaults)
        defaults.set(true, forKey: GlobalConstants.keyLoginRequired)
        defaults.set(false, forKey: GlobalConstants.keyLoginRequired)
        let value = defaults.bool(forKey: GlobalConstants.keyLoginRequired)
        XCTAssertFalse(value, "Login required flag should be false after clearing")
    }

    func testForceRelayConnectionDefaultsToTrue() throws {
        let defaults = try XCTUnwrap(userDefaults)
        defaults.removeObject(forKey: GlobalConstants.keyForceRelayConnection)
        defaults.register(defaults: [GlobalConstants.keyForceRelayConnection: true])
        let value = defaults.bool(forKey: GlobalConstants.keyForceRelayConnection)
        XCTAssertTrue(value, "Force relay connection should default to true")
    }

    func testTVOnDemandFreshInstallDefaultsOnAndMarksMigration() throws {
        let (suiteName, defaults) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = OnDemandPreferenceStore(defaults: defaults)

        XCTAssertTrue(store.loadTVOSDefaultEnabled())
        XCTAssertTrue(defaults.bool(forKey: GlobalConstants.keyConnectOnDemand))
        XCTAssertEqual(
            defaults.integer(forKey: GlobalConstants.keyTVOnDemandPreferenceVersion),
            GlobalConstants.currentTVOnDemandPreferenceVersion
        )
    }

    func testTVOnDemandLegacyFalseMigratesOnlyOnce() throws {
        let (suiteName, defaults) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: GlobalConstants.keyConnectOnDemand)

        let store = OnDemandPreferenceStore(defaults: defaults)

        XCTAssertTrue(store.loadTVOSDefaultEnabled(), "Legacy internal false should adopt the new default")
        store.setTVOSExplicitPreference(false)
        XCTAssertFalse(store.loadTVOSDefaultEnabled(), "A post-migration user opt-out must be preserved")
    }

    func testTVOnDemandVersionedOptOutSurvivesRelaunch() throws {
        let (suiteName, defaults) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = OnDemandPreferenceStore(defaults: defaults)
        _ = store.loadTVOSDefaultEnabled()
        store.setTVOSExplicitPreference(false)

        let reloadedStore = OnDemandPreferenceStore(defaults: defaults)
        XCTAssertFalse(reloadedStore.loadTVOSDefaultEnabled())
    }

    func testDummyFirebaseConfigurationIsRejected() {
        XCTAssertFalse(
            isUsableFirebaseConfiguration(
                ["BUNDLE_ID": "io.netbird.app.tv", "GOOGLE_APP_ID": "dummy"],
                bundleIdentifier: "io.netbird.app.tv"
            )
        )
    }

    func testExplicitlyDisabledFirebaseConfigurationIsRejected() {
        XCTAssertFalse(
            isUsableFirebaseConfiguration(
                ["NETBIRD_FIREBASE_DISABLED": true],
                bundleIdentifier: "io.netbird.app.tv"
            )
        )
    }

    func testFirebaseConfigurationForAnotherBundleIsRejected() {
        XCTAssertFalse(
            isUsableFirebaseConfiguration(
                [
                    "BUNDLE_ID": "io.netbird.app",
                    "GOOGLE_APP_ID": "1:123456789:ios:abcdef123456"
                ],
                bundleIdentifier: "io.netbird.app.tv"
            )
        )
    }

    func testValidFirebaseConfigurationIsAccepted() {
        XCTAssertTrue(
            isUsableFirebaseConfiguration(
                [
                    "BUNDLE_ID": "io.netbird.app.tv",
                    "GOOGLE_APP_ID": "1:123456789:ios:abcdef123456"
                ],
                bundleIdentifier: "io.netbird.app.tv"
            )
        )
    }

    private func makeIsolatedDefaults() throws -> (String, UserDefaults) {
        let suiteName = "io.netbird.tests.on-demand.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }
}
