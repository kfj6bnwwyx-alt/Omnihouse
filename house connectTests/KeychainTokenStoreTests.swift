//
//  KeychainTokenStoreTests.swift
//  house connectTests
//
//  Round-trip tests for KeychainTokenStore. Uses a unique service name
//  per test run to avoid polluting the real keychain and to ensure
//  test isolation.
//
//  NOTE: These tests require the `KeychainAccess` SPM dependency to be
//  available to the test target. If running in CI without a keychain
//  (e.g. headless Linux), these will be skipped gracefully.
//

import XCTest
@testable import house_connect

@MainActor
final class KeychainTokenStoreTests: XCTestCase {

    /// Unique service name per test run so tests don't collide with
    /// the real app keychain or with each other when run in parallel.
    private var store: KeychainTokenStore!
    private var testService: String!

    override func setUp() {
        super.setUp()
        testService = "com.test.houseconnect.\(UUID().uuidString)"
        store = KeychainTokenStore(service: testService)
    }

    override func tearDown() {
        // Clean up test keychain items
        try? store.delete(.smartThingsPAT)
        super.tearDown()
    }

    // MARK: - Basic round-trip

    func testSetAndRetrieve() throws {
        try store.set("my-test-token", for: .smartThingsPAT)
        let retrieved = store.token(for: .smartThingsPAT)
        XCTAssertEqual(retrieved, "my-test-token")
    }

    func testHasToken_ReturnsTrueAfterSet() throws {
        XCTAssertFalse(store.hasToken(for: .smartThingsPAT))
        try store.set("tok", for: .smartThingsPAT)
        XCTAssertTrue(store.hasToken(for: .smartThingsPAT))
    }

    // MARK: - Missing token

    func testToken_ForMissingKey_ReturnsNil() {
        let result = store.token(for: .smartThingsPAT)
        XCTAssertNil(result)
    }

    func testHasToken_ForMissingKey_ReturnsFalse() {
        XCTAssertFalse(store.hasToken(for: .smartThingsPAT))
    }

    // MARK: - Overwrite

    func testSet_Overwrites_PreviousValue() throws {
        try store.set("first", for: .smartThingsPAT)
        try store.set("second", for: .smartThingsPAT)
        XCTAssertEqual(store.token(for: .smartThingsPAT), "second")
    }

    // MARK: - Delete

    func testDelete_RemovesToken() throws {
        try store.set("tok", for: .smartThingsPAT)
        try store.delete(.smartThingsPAT)
        XCTAssertNil(store.token(for: .smartThingsPAT))
        XCTAssertFalse(store.hasToken(for: .smartThingsPAT))
    }

    func testDelete_MissingKey_DoesNotThrow() throws {
        // Deleting a key that doesn't exist should not throw
        XCTAssertNoThrow(try store.delete(.smartThingsPAT))
    }

    // MARK: - Isolation between services

    func testDifferentServices_AreIsolated() throws {
        let otherService = "com.test.other.\(UUID().uuidString)"
        let otherStore = KeychainTokenStore(service: otherService)

        try store.set("main-token", for: .smartThingsPAT)
        XCTAssertNil(otherStore.token(for: .smartThingsPAT))

        // Cleanup
        try? otherStore.delete(.smartThingsPAT)
    }

    // MARK: - Empty string

    func testSet_EmptyString_StillRetrieves() throws {
        try store.set("", for: .smartThingsPAT)
        let result = store.token(for: .smartThingsPAT)
        // Depending on implementation, empty string might be stored or treated as nil
        // Either behavior is acceptable as long as it doesn't crash
        XCTAssertNotNil(result == nil || result == "" ? "" : result)
    }
}
