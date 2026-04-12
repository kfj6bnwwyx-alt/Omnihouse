//
//  SmartThingsAPIClientTests.swift
//  house connectTests
//
//  URLProtocol-stubbed tests for SmartThingsAPIClient. Validates request
//  construction (auth header, method, path), JSON decoding, and error
//  handling for all typed SmartThingsError cases.
//

import XCTest
@testable import house_connect

// MARK: - URLProtocol stub

private final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubProtocol.handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

@MainActor
final class SmartThingsAPIClientTests: XCTestCase {

    private var session: URLSession!
    private var client: SmartThingsAPIClient!
    private let testToken = "test-pat-token-123"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        session = URLSession(configuration: config)
        client = SmartThingsAPIClient(
            tokenProvider: { [testToken] in testToken },
            session: session
        )
    }

    override func tearDown() {
        StubProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Auth header

    func testFetchDevices_SendsBearerToken() async throws {
        var capturedRequest: URLRequest?
        StubProtocol.handler = { request in
            capturedRequest = request
            let json = #"{"items":[]}"#
            return (
                Data(json.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        _ = try await client.fetchDevices()
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"),
                       "Bearer \(testToken)")
    }

    // MARK: - Missing token

    func testFetchDevices_MissingToken_ThrowsMissingToken() async {
        let noTokenClient = SmartThingsAPIClient(
            tokenProvider: { nil },
            session: session
        )
        do {
            _ = try await noTokenClient.fetchDevices()
            XCTFail("Expected missingToken error")
        } catch let error as SmartThingsError {
            if case .missingToken = error { /* pass */ }
            else { XCTFail("Expected missingToken, got \(error)") }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Successful decode

    func testFetchLocations_DecodesItems() async throws {
        StubProtocol.handler = { request in
            XCTAssertTrue(request.url!.path.hasSuffix("/v1/locations"))
            let json = #"{"items":[{"locationId":"loc1","name":"Home"}]}"#
            return (
                Data(json.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        let locations = try await client.fetchLocations()
        XCTAssertEqual(locations.count, 1)
        XCTAssertEqual(locations[0].locationId, "loc1")
        XCTAssertEqual(locations[0].name, "Home")
    }

    func testFetchRooms_UsesCorrectPath() async throws {
        StubProtocol.handler = { request in
            XCTAssertTrue(request.url!.path.contains("/v1/locations/loc1/rooms"))
            let json = #"{"items":[{"roomId":"r1","name":"Kitchen","locationId":"loc1"}]}"#
            return (
                Data(json.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        let rooms = try await client.fetchRooms(locationId: "loc1")
        XCTAssertEqual(rooms.count, 1)
        XCTAssertEqual(rooms[0].name, "Kitchen")
    }

    // MARK: - HTTP error handling

    func testFetchDevices_429_ThrowsRateLimited() async {
        StubProtocol.handler = { request in
            return (
                Data(),
                HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil,
                                headerFields: ["Retry-After": "30"])!
            )
        }

        do {
            _ = try await client.fetchDevices()
            XCTFail("Expected rateLimited error")
        } catch let error as SmartThingsError {
            if case .rateLimited(let retryAfter) = error {
                XCTAssertEqual(retryAfter, 30)
            } else {
                XCTFail("Expected rateLimited, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchDevices_500_ThrowsHTTPError() async {
        StubProtocol.handler = { request in
            let json = #"{"requestId":"req1","error":{"code":"ISE","message":"Server error"}}"#
            return (
                Data(json.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            )
        }

        do {
            _ = try await client.fetchDevices()
            XCTFail("Expected http error")
        } catch let error as SmartThingsError {
            if case .http(let status, let message) = error {
                XCTAssertEqual(status, 500)
                XCTAssertEqual(message, "Server error")
            } else {
                XCTFail("Expected http error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Command encoding

    func testExecuteCommands_SendsPOSTWithCorrectBody() async throws {
        var capturedBody: Data?
        StubProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            capturedBody = request.httpBody
            return (
                Data("{}".utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        try await client.executeCommands(
            deviceId: "dev1",
            commands: [SmartThingsDTO.Command(capability: "switch", command: "on")]
        )

        let body = try XCTUnwrap(capturedBody)
        let decoded = try JSONDecoder().decode(SmartThingsDTO.CommandEnvelope.self, from: body)
        XCTAssertEqual(decoded.commands.count, 1)
        XCTAssertEqual(decoded.commands[0].capability, "switch")
        XCTAssertEqual(decoded.commands[0].command, "on")
    }

    // MARK: - Device status decode

    func testFetchDeviceStatus_DecodesNestedAttributes() async throws {
        StubProtocol.handler = { request in
            let json = """
            {
              "components": {
                "main": {
                  "switch": {
                    "switch": { "value": "on" }
                  },
                  "switchLevel": {
                    "level": { "value": 75 }
                  }
                }
              }
            }
            """
            return (
                Data(json.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        let status = try await client.fetchDeviceStatus(deviceId: "dev1")
        XCTAssertEqual(status.mainAttribute(capability: "switch", attribute: "switch")?.asBool, true)
        XCTAssertEqual(status.mainAttribute(capability: "switchLevel", attribute: "level")?.asInt, 75)
    }

    // MARK: - Rename / delete

    func testRenameDevice_SendsPUT() async throws {
        var capturedMethod: String?
        StubProtocol.handler = { request in
            capturedMethod = request.httpMethod
            return (
                Data("{}".utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        try await client.renameDevice(deviceId: "dev1", newLabel: "New Name")
        XCTAssertEqual(capturedMethod, "PUT")
    }

    func testDeleteDevice_SendsDELETE() async throws {
        var capturedMethod: String?
        StubProtocol.handler = { request in
            capturedMethod = request.httpMethod
            return (
                Data("{}".utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        try await client.deleteDevice(deviceId: "dev1")
        XCTAssertEqual(capturedMethod, "DELETE")
    }
}
