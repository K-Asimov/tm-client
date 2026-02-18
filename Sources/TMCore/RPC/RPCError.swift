import Foundation

public enum RPCError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidPayload
    case rpcFailure(String)
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid RPC URL."
        case .invalidResponse:
            return "Invalid response from Transmission."
        case .invalidPayload:
            return "Unable to parse RPC payload."
        case .rpcFailure(let message):
            return "Transmission RPC error: \(message)"
        case .unauthorized:
            return "Unauthorized. Check RPC credentials."
        }
    }
}
