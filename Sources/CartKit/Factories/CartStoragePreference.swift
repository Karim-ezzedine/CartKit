public enum CartStoragePreference: Sendable {
    /// Prefer SwiftData when available, otherwise fall back to Core Data
    case automatic

    /// Always use Core Data
    case coreData

    /// Force SwiftData (iOS 17+ only)
    case swiftData
}
