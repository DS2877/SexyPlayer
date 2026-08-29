import Foundation

/// Provider failures, each with a calm, user-facing message. Raw networking
/// errors (`NSURLErrorDomain -1009` etc.) are mapped into these before they
/// ever reach the UI.
public enum ProviderError: Error, Equatable, Sendable {
    case offline
    case cannotReachProvider
    case authenticationFailed
    case badResponse
    case playlistMalformed(reason: String)
    case streamUnavailable
    case timedOut
    case cancelled
    case unknown

    /// Short title for an error card.
    public var title: String {
        switch self {
        case .offline:               return "You're offline"
        case .cannotReachProvider:   return "Can't reach your provider"
        case .authenticationFailed:  return "Sign-in failed"
        case .badResponse:           return "Your provider sent something unexpected"
        case .playlistMalformed:     return "This playlist couldn't be read"
        case .streamUnavailable:     return "This channel isn't available right now"
        case .timedOut:              return "Your provider took too long to respond"
        case .cancelled:             return "Cancelled"
        case .unknown:               return "Something went wrong"
        }
    }

    /// One or two sentences under the title.
    public var message: String {
        switch self {
        case .offline:
            return "Check your internet connection and try again."
        case .cannotReachProvider:
            return "We couldn't connect. Your provider may be down, or the address may be wrong."
        case .authenticationFailed:
            return "Your username or password wasn't accepted. Check your provider details."
        case .badResponse:
            return "We reached your provider but couldn't understand the response."
        case .playlistMalformed(let reason):
            return "The playlist file doesn't look valid. (\(reason))"
        case .streamUnavailable:
            return "The stream didn't respond. Try another channel or come back later."
        case .timedOut:
            return "The connection timed out. Try again in a moment."
        case .cancelled:
            return "The request was stopped."
        case .unknown:
            return "Please try again. If it keeps happening, check your provider settings."
        }
    }

    /// Actions an error card should offer.
    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .offline:              return [.retry, .checkConnection]
        case .cannotReachProvider:  return [.retry, .editProvider]
        case .authenticationFailed: return [.editProvider]
        case .timedOut, .streamUnavailable, .badResponse, .unknown:
            return [.retry]
        case .playlistMalformed:    return [.editProvider]
        case .cancelled:            return [.retry]
        }
    }

    public enum RecoveryAction: Sendable {
        case retry
        case checkConnection
        case editProvider

        public var label: String {
            switch self {
            case .retry:           return "Try Again"
            case .checkConnection: return "Check Connection"
            case .editProvider:    return "Edit Provider"
            }
        }
    }

    /// Map an arbitrary `Error` (often a `URLError`) into a `ProviderError`.
    public static func from(_ error: Error) -> ProviderError {
        if let providerError = error as? ProviderError { return providerError }
        if error is CancellationError { return .cancelled }
        let urlError = error as? URLError
        switch urlError?.code {
        case .some(.notConnectedToInternet), .some(.dataNotAllowed):
            return .offline
        case .some(.timedOut):
            return .timedOut
        case .some(.cannotFindHost), .some(.cannotConnectToHost),
             .some(.dnsLookupFailed), .some(.networkConnectionLost):
            return .cannotReachProvider
        case .some(.userAuthenticationRequired):
            return .authenticationFailed
        case .some(.cancelled):
            return .cancelled
        default:
            return .unknown
        }
    }
}
