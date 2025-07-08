import Foundation

// MARK: - API Error Types

enum APIError: Error, LocalizedError, Equatable {
    case networkError(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized(message: String)
    case notFound(message: String)
    case badRequest(message: String)
    case rateLimited(message: String)
    case decodingError(Error)
    case timeout
    case cancelled
    case invalidURL
    case invalidResponse
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown server error")"
        case .unauthorized(let message):
            return "Unauthorized: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .rateLimited(let message):
            return "Rate limited: \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .serverError:
            return "The server encountered an error. Please try again later."
        case .unauthorized:
            return "Check your API key and ensure it's valid."
        case .notFound:
            return "The requested resource was not found."
        case .badRequest:
            return "Check your request parameters and try again."
        case .rateLimited:
            return "You're making too many requests. Please wait and try again."
        case .decodingError:
            return "There was an error parsing the server response."
        case .timeout:
            return "The request took too long. Check your connection and try again."
        case .cancelled:
            return "The request was cancelled."
        case .invalidURL:
            return "The URL is invalid. Please check the server address."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError),
             (.timeout, .timeout),
             (.cancelled, .cancelled),
             (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse):
            return true
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.unauthorized(let lhsMessage), .unauthorized(let rhsMessage)),
             (.notFound(let lhsMessage), .notFound(let rhsMessage)),
             (.badRequest(let lhsMessage), .badRequest(let rhsMessage)),
             (.rateLimited(let lhsMessage), .rateLimited(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.decodingError, .decodingError),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

// MARK: - Health Status

enum HealthStatus: String, Codable, CaseIterable {
    case healthy
    case degraded
    case unhealthy
}

// MARK: - API Response Types

struct APIErrorResponse: Codable {
    let type: String
    let title: String
    let status: Int
    let detail: String
    let instance: String
    let timestamp: String
    let requestId: String
}

struct HealthResponse: Codable {
    let status: HealthStatus
    let version: String
    let uptime: Int
    let terminals: Int
}

struct TerminalListResponse: Codable {
    let terminals: [Terminal]
    let activeTerminalId: String?
}

struct TerminalDetailsResponse: Codable {
    let terminal: Terminal
    let buffer: [String]
}

struct TerminalSelectResponse: Codable {
    let success: Bool
    let activeTerminalId: String
}

struct TerminalInputResponse: Codable {
    let success: Bool
    let sequence: Int
}

struct TerminalResizeResponse: Codable {
    let success: Bool
}

// MARK: - Request Bodies

struct TerminalInputRequest: Codable {
    let data: String
}

struct TerminalResizeRequest: Codable {
    let cols: Int
    let rows: Int
}