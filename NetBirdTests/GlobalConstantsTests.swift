// Modified for Trentfinity VPN on 2026-11-05.
//
//  GlobalConstantsTests.swift
//  NetBirdTests
//

import XCTest
@testable import NetBird

final class GlobalConstantsTests: XCTestCase {

    func testForceRelayConnectionKey() {
        XCTAssertEqual(GlobalConstants.keyForceRelayConnection, "isConnectionForceRelayed")
    }

    func testLoginRequiredKey() {
        XCTAssertEqual(GlobalConstants.keyLoginRequired, "netbird.loginRequired")
    }

    func testUserPreferencesSuiteName() {
        XCTAssertEqual(GlobalConstants.userPreferencesSuiteName, "group.com.trentfinity.vpn")
    }
}
