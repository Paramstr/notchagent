import Foundation

enum CapyAPIError: Error, LocalizedError {
    case access, rateLimited, unavailable, tooManyThreads
    var errorDescription: String? {
        switch self {
        case .access: "Capy denied access. Check the key and its project permissions."
        case .rateLimited: "Capy rate limit reached. Retrying in one minute."
        case .unavailable: "Capy is unavailable. Updates will resume after reconnecting."
        case .tooManyThreads: "Capy project is too large to monitor completely. Use a key with fewer projects."
        }
    }
}
