import Foundation

/// HTTP client for communicating with the Mobile Terminal server
class APIClient {
    // MARK: - Properties
    
    let baseURL: URL
    let apiKey: String
    private let urlSession: URLSessionProtocol
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(baseURL: URL, apiKey: String, urlSession: URLSessionProtocol = URLSession.shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.urlSession = urlSession
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
        
        // Configure JSON encoder/decoder for proper date handling
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Health API
    
    /// Get server health status
    func getHealth() async throws -> HealthResponse {
        let url = baseURL.appendingPathComponent("api/health")
        let request = URLRequest(url: url)
        
        return try await performRequest(request, authenticated: false)
    }
    
    // MARK: - Terminal API
    
    /// Get list of all terminals
    func getTerminals() async throws -> TerminalListResponse {
        let url = baseURL.appendingPathComponent("api/terminals")
        let request = createAuthenticatedRequest(url: url, method: "GET")
        
        return try await performRequest(request, authenticated: true)
    }
    
    /// Get specific terminal details
    func getTerminal(id: String) async throws -> TerminalDetailsResponse {
        let url = baseURL.appendingPathComponent("api/terminals/\(id)")
        let request = createAuthenticatedRequest(url: url, method: "GET")
        
        return try await performRequest(request, authenticated: true)
    }
    
    /// Select a terminal as active
    func selectTerminal(id: String) async throws -> TerminalSelectResponse {
        let url = baseURL.appendingPathComponent("api/terminals/\(id)/select")
        var request = createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return try await performRequest(request, authenticated: true)
    }
    
    /// Send input to a terminal
    func sendInput(terminalId: String, data: String) async throws -> TerminalInputResponse {
        let url = baseURL.appendingPathComponent("api/terminals/\(terminalId)/input")
        var request = createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = TerminalInputRequest(data: data)
        request.httpBody = try jsonEncoder.encode(requestBody)
        
        return try await performRequest(request, authenticated: true)
    }
    
    /// Resize a terminal
    func resizeTerminal(terminalId: String, cols: Int, rows: Int) async throws -> TerminalResizeResponse {
        let url = baseURL.appendingPathComponent("api/terminals/\(terminalId)/resize")
        var request = createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = TerminalResizeRequest(cols: cols, rows: rows)
        request.httpBody = try jsonEncoder.encode(requestBody)
        
        return try await performRequest(request, authenticated: true)
    }
    
    // MARK: - Private Methods
    
    private func createAuthenticatedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }
    
    private func performRequest<T: Codable>(_ request: URLRequest, authenticated: Bool) async throws -> T {
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode the response
                do {
                    return try jsonDecoder.decode(T.self, from: data)
                } catch {
                    throw APIError.decodingError(error)
                }
                
            case 400:
                let errorResponse = try? jsonDecoder.decode(APIErrorResponse.self, from: data)
                throw APIError.badRequest(message: errorResponse?.detail ?? "Bad request")
                
            case 401:
                let errorResponse = try? jsonDecoder.decode(APIErrorResponse.self, from: data)
                throw APIError.unauthorized(message: errorResponse?.detail ?? "Unauthorized")
                
            case 404:
                let errorResponse = try? jsonDecoder.decode(APIErrorResponse.self, from: data)
                throw APIError.notFound(message: errorResponse?.detail ?? "Not found")
                
            case 429:
                let errorResponse = try? jsonDecoder.decode(APIErrorResponse.self, from: data)
                throw APIError.rateLimited(message: errorResponse?.detail ?? "Rate limited")
                
            case 500...599:
                let errorResponse = try? jsonDecoder.decode(APIErrorResponse.self, from: data)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse?.detail)
                
            default:
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unexpected status code")
            }
            
        } catch {
            // Handle URLErrors specifically
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw APIError.timeout
                case .cancelled:
                    throw APIError.cancelled
                case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                    throw APIError.networkError(urlError)
                default:
                    throw APIError.networkError(urlError)
                }
            }
            
            // Re-throw APIErrors as-is
            if error is APIError {
                throw error
            }
            
            // Wrap other errors
            throw APIError.unknown(error)
        }
    }
}