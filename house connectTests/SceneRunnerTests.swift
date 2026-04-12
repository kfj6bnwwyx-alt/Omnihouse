//
//  SceneRunnerTests.swift
//  house connectTests
//
//  Tests for SceneRunner: parallel execution, partial failures,
//  empty scenes, and full-success / complete-failure semantics.
//

import XCTest
@testable import house_connect

// MARK: - Mock provider

@MainActor
private final class MockProvider: AccessoryProvider {
    let id: ProviderID
    let displayName: String
    var homes: [Home] = []
    var rooms: [Room] = []
    var accessories: [Accessory] = []
    var authorizationState: ProviderAuthorizationState = .authorized

    /// Commands that were executed, for verification.
    var executedCommands: [(AccessoryCommand, AccessoryID)] = []

    /// If non-nil, `execute` throws this error for the given accessory IDs.
    var failingIDs: Set<String> = []
    var failError: Error = ProviderError.underlying("Mock failure")

    init(id: ProviderID, displayName: String = "Mock") {
        self.id = id
        self.displayName = displayName
    }

    func start() async {}

    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        executedCommands.append((command, accessoryID))
        if failingIDs.contains(accessoryID.nativeID) {
            throw failError
        }
    }
}

// MARK: - Tests

@MainActor
final class SceneRunnerTests: XCTestCase {

    private func makeRegistry(provider: MockProvider) -> ProviderRegistry {
        let registry = ProviderRegistry()
        registry.register(provider)
        return registry
    }

    private func makeID(provider: ProviderID = .smartThings, native: String = "dev1") -> AccessoryID {
        AccessoryID(provider: provider, nativeID: native)
    }

    // MARK: - Empty scene

    func testRun_EmptyScene_ReturnsZeroCounts() async {
        let registry = makeRegistry(provider: MockProvider(id: .smartThings))
        let runner = SceneRunner(registry: registry)
        let scene = HCScene(name: "Empty", iconSystemName: "star", actions: [])

        let result = await runner.run(scene)
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.succeeded, 0)
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertFalse(result.isFullSuccess, "Empty scene is not 'full success'")
    }

    // MARK: - Full success

    func testRun_AllActionsSucceed_FullSuccess() async {
        let provider = MockProvider(id: .smartThings)
        let registry = makeRegistry(provider: provider)
        let runner = SceneRunner(registry: registry)

        let id1 = makeID(native: "dev1")
        let id2 = makeID(native: "dev2")
        let scene = HCScene(name: "Good Night", iconSystemName: "moon", actions: [
            SceneAction(accessoryID: id1, command: .setPower(false)),
            SceneAction(accessoryID: id2, command: .setBrightness(0.0)),
        ])

        let result = await runner.run(scene)
        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.succeeded, 2)
        XCTAssertTrue(result.isFullSuccess)
        XCTAssertFalse(result.isCompleteFailure)
        XCTAssertEqual(provider.executedCommands.count, 2)
    }

    // MARK: - Partial failure

    func testRun_OneActionFails_PartialSuccess() async {
        let provider = MockProvider(id: .smartThings)
        provider.failingIDs = ["dev2"]
        let registry = makeRegistry(provider: provider)
        let runner = SceneRunner(registry: registry)

        let id1 = makeID(native: "dev1")
        let id2 = makeID(native: "dev2")
        let scene = HCScene(name: "Movie Time", iconSystemName: "film", actions: [
            SceneAction(accessoryID: id1, command: .setPower(true)),
            SceneAction(accessoryID: id2, command: .setVolume(50)),
        ])

        let result = await runner.run(scene)
        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.succeeded, 1)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertFalse(result.isFullSuccess)
        XCTAssertFalse(result.isCompleteFailure)
        XCTAssertEqual(result.failures[0].accessoryID, id2)
    }

    // MARK: - Complete failure

    func testRun_AllActionsFail_CompleteFailure() async {
        let provider = MockProvider(id: .smartThings)
        provider.failingIDs = ["dev1", "dev2"]
        let registry = makeRegistry(provider: provider)
        let runner = SceneRunner(registry: registry)

        let id1 = makeID(native: "dev1")
        let id2 = makeID(native: "dev2")
        let scene = HCScene(name: "Broken", iconSystemName: "xmark", actions: [
            SceneAction(accessoryID: id1, command: .setPower(true)),
            SceneAction(accessoryID: id2, command: .setPower(true)),
        ])

        let result = await runner.run(scene)
        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.succeeded, 0)
        XCTAssertTrue(result.isCompleteFailure)
        XCTAssertFalse(result.isFullSuccess)
    }

    // MARK: - Missing provider

    func testRun_UnknownProvider_ReportsFailure() async {
        // Registry has SmartThings, but scene targets Sonos
        let provider = MockProvider(id: .smartThings)
        let registry = makeRegistry(provider: provider)
        let runner = SceneRunner(registry: registry)

        let sonosID = AccessoryID(provider: .sonos, nativeID: "speaker1")
        let scene = HCScene(name: "Sonos Only", iconSystemName: "speaker", actions: [
            SceneAction(accessoryID: sonosID, command: .play),
        ])

        let result = await runner.run(scene)
        XCTAssertEqual(result.total, 1)
        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.failures.count, 1)
    }
}
