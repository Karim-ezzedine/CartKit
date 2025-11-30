import Foundation

/// High-level error type used by MultiCart core.
public enum MultiCartError: Error, Equatable, Sendable {
    case validationFailed(reason: String)
    case pricingFailed(reason: String)
    case conflict(reason: String)
    case storageFailure(reason: String)
    case unknown
}

