//
//  ProviderRegistryTests.swift
//  house connectTests
//
//  Tests for ProviderRegistry: registration, aggregation of accessories/
//  rooms/homes, command routing, and room CRUD fan-out.
//

import XCTest
@testable import house_connect

// MARK: - Mock provider (shared across registry tests)

@MainActor
private final class StubProvider: AccessoryProvider {
    let id: ProviderID
    let displayName: String
    var homes: [Home]
    var rooms: [Room]
    var accessories: [Accessory]
    var authorizationState: ProviderAuthorizationState = .authorized

    var lastCommand: AccessoryCommand?
    var lastCommandTarget: AccessoryID?
    var shouldThrow: Error?
    var startCalled = false
    var lastRenamedID: AccessoryID?
    var lastRenamedName: String?
    var lastCreatedRoomName: String?
    var lastDeletedRoomID: String?
    var lastAssignedToRoomID: String?

    init(
        id: ProviderID,
        displayName: String = "Stub",
        homes: [Home] = [],
        rooms: [Room] = [],
        accessories: [Accessory] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.homes = homes
        self.rooms = rooms
        self.accessories = accessories
    }

    func start() async { startCalled = true }

    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        lastCommand = command
        lastCommandTarget = accessoryID
        if let e = shouldThrow { throw e }
    }

    func rename(accessory accessoryID: AccessoryID, to newName: String) async throws {
        lastRenamedID = accessoryID
        lastRenamedName = newName
    }

    func createRoom(named name: String, inHomeWithID homeID: String) async throws -> Room {
        lastCreatedRoomName = name
        return Room(id: "new-room", name: name, homeID: homeID, provider: id)
    }

    func deleteRoom(roomID: String) async throws {
        lastDeletedRoomID = roomID
    }

    func assignAccessory(_ accessoryID: AccessoryID, toRoomID roomID: String?) async throws {
        lastAssignedToRoomID = roomID
    }
}

// MARK: - Tests

@MainActor
final class ProviderRegistryTests: XCTestCase {

    // MARK: - Registration

    func testRegister_AddsProvider() {
        let registry = ProviderRegistry()
        let p = StubProvider(id: .smartThings)
        registry.register(p)
        XCTAssertEqual(registry.providers.count, 1)
    }

    func testRegister_DuplicateIgnored() {
        let registry = ProviderRegistry()
        let p1 = StubProvider(id: .smartThings)
        let p2 = StubProvider(id: .smartThings)
        registry.register(p1)
        registry.register(p2)
        XCTAssertEqual(registry.providers.count, 1)
    }

    func testProvider_Lookup() {
        let registry = ProviderRegistry()
        let hk = StubProvider(id: .homeKit)
        let st = StubProvider(id: .smartThings)
        registry.register(hk)
        registry.register(st)
        XCTAssertNotNil(registry.provider(for: .homeKit))
        XCTAssertNotNil(registry.provider(for: .smartThings))
        XCTAssertNil(registry.provider(for: .sonos))
    }

    // MARK: - Aggregation

    func testAllAccessories_FlattensProviders() {
        let hk = StubProvider(id: .homeKit, accessories: [
            makeAccessory(provider: .homeKit, name: "Light 1"),
        ])
        let st = StubProvider(id: .smartThings, accessories: [
            makeAccessory(provider: .smartThings, name: "Light 2"),
            makeAccessory(provider: .smartThings, name: "Sensor"),
        ])
        let registry = ProviderRegistry()
        registry.register(hk)
        registry.register(st)

        XCTAssertEqual(registry.allAccessories.count, 3)
    }

    func testAllRooms_FlattensProviders() {
        let hk = StubProvider(id: .homeKit, rooms: [
            Room(id: "r1", name: "Kitchen", homeID: "h1", provider: .homeKit),
        ])
        let st = StubProvider(id: .smartThings, rooms: [
            Room(id: "r2", name: "Bedroom", homeID: "h2", provider: .smartThings),
        ])
        let registry = ProviderRegistry()
        registry.register(hk)
        registry.register(st)

        XCTAssertEqual(registry.allRooms.count, 2)
    }

    func testAllHomes_FlattensProviders() {
        let hk = StubProvider(id: .homeKit, homes: [
            Home(id: "h1", name: "Main Home", isPrimary: true, provider: .homeKit),
        ])
        let registry = ProviderRegistry()
        registry.register(hk)

        XCTAssertEqual(registry.allHomes.count, 1)
        XCTAssertEqual(registry.allHomes[0].name, "Main Home")
    }

    // MARK: - startAll

    func testStartAll_CallsStartOnEachProvider() async {
        let hk = StubProvider(id: .homeKit)
        let st = StubProvider(id: .smartThings)
        let registry = ProviderRegistry()
        registry.register(hk)
        registry.register(st)

        await registry.startAll()
        XCTAssertTrue(hk.startCalled)
        XCTAssertTrue(st.startCalled)
    }

    // MARK: - Command routing

    func testExecute_RoutesToCorrectProvider() async throws {
        let hk = StubProvider(id: .homeKit)
        let st = StubProvider(id: .smartThings)
        let registry = ProviderRegistry()
        registry.register(hk)
        registry.register(st)

        let stID = AccessoryID(provider: .smartThings, nativeID: "dev1")
        try await registry.execute(.setPower(true), on: stID)

        XCTAssertNil(hk.lastCommand)
        XCTAssertEqual(st.lastCommand, .setPower(true))
        XCTAssertEqual(st.lastCommandTarget, stID)
    }

    func testExecute_UnknownProvider_ThrowsNotFound() async {
        let registry = ProviderRegistry()
        let sonosID = AccessoryID(provider: .sonos, nativeID: "s1")

        do {
            try await registry.execute(.play, on: sonosID)
            XCTFail("Expected accessoryNotFound")
        } catch let error as ProviderError {
            guard case .accessoryNotFound = error else {
                XCTFail("Expected accessoryNotFound, got \(error)"); return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Rename

    func testRename_DelegatesToProvider() async throws {
        let st = StubProvider(id: .smartThings)
        let registry = ProviderRegistry()
        registry.register(st)

        let id = AccessoryID(provider: .smartThings, nativeID: "dev1")
        try await registry.rename(accessoryID: id, to: "New Name")

        XCTAssertEqual(st.lastRenamedID, id)
        XCTAssertEqual(st.lastRenamedName, "New Name")
    }

    // MARK: - Room CRUD

    func testCreateRoom_RoutesToHomeOwner() async throws {
        let hk = StubProvider(id: .homeKit, homes: [
            Home(id: "h1", name: "My Home", isPrimary: true, provider: .homeKit),
        ])
        let registry = ProviderRegistry()
        registry.register(hk)

        let room = try await registry.createRoom(named: "Office", inHomeWithID: "h1")
        XCTAssertEqual(room.name, "Office")
        XCTAssertEqual(hk.lastCreatedRoomName, "Office")
    }

    func testCreateRoom_UnknownHome_Throws() async {
        let registry = ProviderRegistry()
        do {
            _ = try await registry.createRoom(named: "X", inHomeWithID: "no-such-home")
            XCTFail("Expected error")
        } catch {
            // pass
        }
    }

    func testDeleteRoom_DelegatesToProvider() async throws {
        let st = StubProvider(id: .smartThings, rooms: [
            Room(id: "r1", name: "Kitchen", homeID: "h1", provider: .smartThings),
        ])
        let registry = ProviderRegistry()
        registry.register(st)

        let room = Room(id: "r1", name: "Kitchen", homeID: "h1", provider: .smartThings)
        try await registry.deleteRoom(room)
        XCTAssertEqual(st.lastDeletedRoomID, "r1")
    }

    // MARK: - Cross-provider assignment guard

    func testAssignAccessory_CrossProvider_Throws() async {
        let hk = StubProvider(id: .homeKit, rooms: [
            Room(id: "hk-room", name: "Kitchen", homeID: "h1", provider: .homeKit),
        ])
        let st = StubProvider(id: .smartThings)
        let registry = ProviderRegistry()
        registry.register(hk)
        registry.register(st)

        let stAccessory = AccessoryID(provider: .smartThings, nativeID: "dev1")
        do {
            try await registry.assignAccessory(stAccessory, toRoomID: "hk-room")
            XCTFail("Expected unsupportedCommand for cross-provider assignment")
        } catch let error as ProviderError {
            guard case .unsupportedCommand = error else {
                XCTFail("Expected unsupportedCommand, got \(error)"); return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeAccessory(provider: ProviderID, name: String) -> Accessory {
        Accessory(
            id: AccessoryID(provider: provider, nativeID: "\(provider.rawValue)-\(UUID().uuidString)"),
            name: name,
            category: .light,
            roomID: nil,
            isReachable: true,
            capabilities: []
        )
    }
}
