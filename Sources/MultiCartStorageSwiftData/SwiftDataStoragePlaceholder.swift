import MultiCartCore

#if canImport(SwiftData)
import SwiftData

/// Entry point for the SwiftData-based CartStore implementation.
@available(iOS 17, *)
public struct SwiftDataCartStore {
    public init() { }
}
#endif // canImport(SwiftData)

