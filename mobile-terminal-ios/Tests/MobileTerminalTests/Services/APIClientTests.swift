import XCTest
import Foundation
@testable import MobileTerminal

final class APIClientTests: XCTestCase {
    var apiClient: APIClient!
    var mockURLSession: MockURLSession!
    var baseURL: URL!
    var apiKey: String!
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        baseURL = URL(string: "http://localhost:8092")!
        apiKey = "test-api-key-12345"
        apiClient = APIClient(baseURL: baseURL, apiKey: apiKey, urlSession: mockURLSession)
    }
    
    override func tearDown() {
        apiClient = nil
        mockURLSession = nil
        baseURL = nil
        apiKey = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(apiClient.baseURL, baseURL)
        XCTAssertEqual(apiClient.apiKey, apiKey)
    }
    
    func testInitializationWithDefaultURLSession() {
        let client = APIClient(baseURL: baseURL, apiKey: apiKey)
        XCTAssertNotNil(client)
    }
    
    // MARK: - Health Check Tests
    
    func testGetHealthSuccess() async throws {
        // Arrange
        let expectedHealth = HealthResponse(
            status: .healthy,
            version: "1.0.0",
            uptime: 3600,
            terminals: 3
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedHealth)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/health"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let health = try await apiClient.getHealth()
        
        // Assert
        XCTAssertEqual(health.status, .healthy)
        XCTAssertEqual(health.version, "1.0.0")
        XCTAssertEqual(health.uptime, 3600)
        XCTAssertEqual(health.terminals, 3)
        
        // Verify request
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/api/health")
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "GET")
        XCTAssertNil(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"))
    }
    
    func testGetHealthDegradedStatus() async throws {
        // Arrange
        let expectedHealth = HealthResponse(
            status: .degraded,
            version: "1.0.0",
            uptime: 1800,
            terminals: 1
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedHealth)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/health"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let health = try await apiClient.getHealth()
        
        // Assert
        XCTAssertEqual(health.status, .degraded)
    }
    
    func testGetHealthNetworkError() async {
        // Arrange
        mockURLSession.error = URLError(.notConnectedToInternet)
        
        // Act & Assert
        do {
            _ = try await apiClient.getHealth()
            XCTFail("Expected APIError.networkError")
        } catch {
            if case APIError.networkError(let underlyingError) = error {
                XCTAssertTrue(underlyingError is URLError)
            } else {
                XCTFail("Expected APIError.networkError, got: \(error)")
            }
        }
    }
    
    func testGetHealthServerError() async {
        // Arrange
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/health"),
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        mockURLSession.data = Data()
        
        // Act & Assert
        do {
            _ = try await apiClient.getHealth()
            XCTFail("Expected APIError.serverError")
        } catch {
            if case APIError.serverError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected APIError.serverError, got: \(error)")
            }
        }
    }
    
    // MARK: - Terminal List Tests
    
    func testGetTerminalsSuccess() async throws {
        // Arrange
        let expectedTerminals = [
            Terminal.mock(name: "Terminal 1"),
            Terminal.mock(name: "Terminal 2")
        ]
        let expectedResponse = TerminalListResponse(
            terminals: expectedTerminals,
            activeTerminalId: expectedTerminals[0].id
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let response = try await apiClient.getTerminals()
        
        // Assert
        XCTAssertEqual(response.terminals.count, 2)
        XCTAssertEqual(response.terminals[0].name, "Terminal 1")
        XCTAssertEqual(response.terminals[1].name, "Terminal 2")
        XCTAssertEqual(response.activeTerminalId, expectedTerminals[0].id)
        
        // Verify request
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/api/terminals")
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), apiKey)
    }
    
    func testGetTerminalsUnauthorized() async {
        // Arrange
        let errorResponse = APIErrorResponse(
            type: "https://httpstatuses.com/401",
            title: "Unauthorized",
            status: 401,
            detail: "Invalid API key",
            instance: "/api/terminals",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            requestId: "test-request-id"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try! encoder.encode(errorResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals"),
            statusCode: 401,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act & Assert
        do {
            _ = try await apiClient.getTerminals()
            XCTFail("Expected APIError.unauthorized")
        } catch {
            if case APIError.unauthorized(let message) = error {
                XCTAssertEqual(message, "Invalid API key")
            } else {
                XCTFail("Expected APIError.unauthorized, got: \(error)")
            }
        }
    }
    
    func testGetTerminalsEmptyList() async throws {
        // Arrange
        let expectedResponse = TerminalListResponse(
            terminals: [],
            activeTerminalId: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let response = try await apiClient.getTerminals()
        
        // Assert
        XCTAssertEqual(response.terminals.count, 0)
        XCTAssertNil(response.activeTerminalId)
    }
    
    // MARK: - Terminal Details Tests
    
    func testGetTerminalSuccess() async throws {
        // Arrange
        let terminal = Terminal.mock()
        let expectedBuffer = ["line 1", "line 2", "line 3"]
        let expectedResponse = TerminalDetailsResponse(
            terminal: terminal,
            buffer: expectedBuffer
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminal.id)"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let response = try await apiClient.getTerminal(id: terminal.id)
        
        // Assert
        XCTAssertEqual(response.terminal.id, terminal.id)
        XCTAssertEqual(response.buffer, expectedBuffer)
        
        // Verify request
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/api/terminals/\(terminal.id)")
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), apiKey)
    }
    
    func testGetTerminalNotFound() async {
        // Arrange
        let terminalId = "non-existent-id"
        let errorResponse = APIErrorResponse(
            type: "https://httpstatuses.com/404",
            title: "Not Found",
            status: 404,
            detail: "Terminal not found",
            instance: "/api/terminals/\(terminalId)",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            requestId: "test-request-id"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try! encoder.encode(errorResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminalId)"),
            statusCode: 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act & Assert
        do {
            _ = try await apiClient.getTerminal(id: terminalId)
            XCTFail("Expected APIError.notFound")
        } catch {
            if case APIError.notFound(let message) = error {
                XCTAssertEqual(message, "Terminal not found")
            } else {
                XCTFail("Expected APIError.notFound, got: \(error)")
            }
        }
    }
    
    // MARK: - Terminal Selection Tests
    
    func testSelectTerminalSuccess() async throws {
        // Arrange
        let terminalId = "terminal-id-123"
        let expectedResponse = TerminalSelectResponse(
            success: true,
            activeTerminalId: terminalId
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminalId)/select"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let response = try await apiClient.selectTerminal(id: terminalId)
        
        // Assert
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.activeTerminalId, terminalId)
        
        // Verify request
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/api/terminals/\(terminalId)/select")
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), apiKey)
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testSelectTerminalFailure() async {
        // Arrange
        let terminalId = "invalid-terminal-id"
        let errorResponse = APIErrorResponse(
            type: "https://httpstatuses.com/404",
            title: "Not Found",
            status: 404,
            detail: "Terminal not found or selection failed",
            instance: "/api/terminals/\(terminalId)/select",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            requestId: "test-request-id"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try! encoder.encode(errorResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminalId)/select"),
            statusCode: 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act & Assert
        do {
            _ = try await apiClient.selectTerminal(id: terminalId)
            XCTFail("Expected APIError.notFound")
        } catch {
            if case APIError.notFound(let message) = error {
                XCTAssertEqual(message, "Terminal not found or selection failed")
            } else {
                XCTFail("Expected APIError.notFound, got: \(error)")
            }
        }
    }
    
    // MARK: - Terminal Input Tests
    
    func testSendInputSuccess() async throws {
        // Arrange
        let terminalId = "terminal-id-123"
        let inputData = "ls -la\n"
        let expectedResponse = TerminalInputResponse(
            success: true,
            sequence: 1234567890
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminalId)/input"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let response = try await apiClient.sendInput(terminalId: terminalId, data: inputData)
        
        // Assert
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.sequence, 1234567890)
        
        // Verify request
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/api/terminals/\(terminalId)/input")
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), apiKey)
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        
        // Verify request body
        if let httpBody = mockURLSession.lastRequest?.httpBody,
           let requestData = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] {
            XCTAssertEqual(requestData["data"] as? String, inputData)
        } else {
            XCTFail("Expected request body with input data")
        }
    }
    
    func testSendInputBadRequest() async {
        // Arrange
        let terminalId = "terminal-id-123"
        let inputData = ""
        let errorResponse = APIErrorResponse(
            type: "https://httpstatuses.com/400",
            title: "Bad Request",
            status: 400,
            detail: "Missing input data",
            instance: "/api/terminals/\(terminalId)/input",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            requestId: "test-request-id"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try! encoder.encode(errorResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminalId)/input"),
            statusCode: 400,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act & Assert
        do {
            _ = try await apiClient.sendInput(terminalId: terminalId, data: inputData)
            XCTFail("Expected APIError.badRequest")
        } catch {
            if case APIError.badRequest(let message) = error {
                XCTAssertEqual(message, "Missing input data")
            } else {
                XCTFail("Expected APIError.badRequest, got: \(error)")
            }
        }
    }
    
    // MARK: - Terminal Resize Tests
    
    func testResizeTerminalSuccess() async throws {
        // Arrange
        let terminalId = "terminal-id-123"
        let cols = 80
        let rows = 24
        let expectedResponse = TerminalResizeResponse(success: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(expectedResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminalId)/resize"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act
        let response = try await apiClient.resizeTerminal(terminalId: terminalId, cols: cols, rows: rows)
        
        // Assert
        XCTAssertTrue(response.success)
        
        // Verify request
        XCTAssertEqual(mockURLSession.lastRequest?.url?.path, "/api/terminals/\(terminalId)/resize")
        XCTAssertEqual(mockURLSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), apiKey)
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        
        // Verify request body
        if let httpBody = mockURLSession.lastRequest?.httpBody,
           let requestData = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] {
            XCTAssertEqual(requestData["cols"] as? Int, cols)
            XCTAssertEqual(requestData["rows"] as? Int, rows)
        } else {
            XCTFail("Expected request body with resize dimensions")
        }
    }
    
    func testResizeTerminalInvalidDimensions() async {
        // Arrange
        let terminalId = "terminal-id-123"
        let cols = 0
        let rows = -1
        let errorResponse = APIErrorResponse(
            type: "https://httpstatuses.com/400",
            title: "Bad Request",
            status: 400,
            detail: "Invalid dimensions",
            instance: "/api/terminals/\(terminalId)/resize",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            requestId: "test-request-id"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try! encoder.encode(errorResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals/\(terminalId)/resize"),
            statusCode: 400,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act & Assert
        do {
            _ = try await apiClient.resizeTerminal(terminalId: terminalId, cols: cols, rows: rows)
            XCTFail("Expected APIError.badRequest")
        } catch {
            if case APIError.badRequest(let message) = error {
                XCTAssertEqual(message, "Invalid dimensions")
            } else {
                XCTFail("Expected APIError.badRequest, got: \(error)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidJSONResponse() async {
        // Arrange
        mockURLSession.data = Data("invalid json".utf8)
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/health"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act & Assert
        do {
            _ = try await apiClient.getHealth()
            XCTFail("Expected APIError.decodingError")
        } catch {
            if case APIError.decodingError = error {
                // Expected
            } else {
                XCTFail("Expected APIError.decodingError, got: \(error)")
            }
        }
    }
    
    func testTimeoutError() async {
        // Arrange
        mockURLSession.error = URLError(.timedOut)
        
        // Act & Assert
        do {
            _ = try await apiClient.getHealth()
            XCTFail("Expected APIError.timeout")
        } catch {
            if case APIError.timeout = error {
                // Expected
            } else {
                XCTFail("Expected APIError.timeout, got: \(error)")
            }
        }
    }
    
    func testRateLimitError() async {
        // Arrange
        let errorResponse = APIErrorResponse(
            type: "https://httpstatuses.com/429",
            title: "Too Many Requests",
            status: 429,
            detail: "Rate limit exceeded",
            instance: "/api/terminals",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            requestId: "test-request-id"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try! encoder.encode(errorResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/api/terminals"),
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        // Act & Assert
        do {
            _ = try await apiClient.getTerminals()
            XCTFail("Expected APIError.rateLimited")
        } catch {
            if case APIError.rateLimited(let message) = error {
                XCTAssertEqual(message, "Rate limit exceeded")
            } else {
                XCTFail("Expected APIError.rateLimited, got: \(error)")
            }
        }
    }
    
    // MARK: - Request Cancellation Tests
    
    func testRequestCancellation() async {
        // Arrange
        mockURLSession.error = URLError(.cancelled)
        
        // Act & Assert
        do {
            _ = try await apiClient.getHealth()
            XCTFail("Expected APIError.cancelled")
        } catch {
            if case APIError.cancelled = error {
                // Expected
            } else {
                XCTFail("Expected APIError.cancelled, got: \(error)")
            }
        }
    }
}

// MARK: - Mock URL Session

class MockURLSession: URLSessionProtocol {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var lastRequest: URLRequest?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = error {
            throw error
        }
        
        guard let data = data, let response = response else {
            throw URLError(.unknown)
        }
        
        return (data, response)
    }
}