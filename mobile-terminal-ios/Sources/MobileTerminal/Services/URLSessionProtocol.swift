import Foundation

/// Protocol for URLSession to enable testing with mock implementations
public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Extension to make URLSession conform to URLSessionProtocol
extension URLSession: URLSessionProtocol {
    // URLSession already implements this method, so no additional implementation needed
}