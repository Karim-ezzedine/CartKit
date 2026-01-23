/// Policies controlling cart retention and cleanup.
///
/// Notes:
/// - "Archived" carts are carts that are not `.active` (checkedOut/cancelled/expired).
/// - Cleanup deletes carts from storage; it never modifies carts in-place.
/// - Scope is `(storeID + profileID? + sessionID?)`.
public struct CartLifecyclePolicy: Sendable, Hashable {
    
    /// Keep at most N non-active carts per scope `(storeID + profileID? + sessionID?)`.
    /// Most recently updated carts are kept; older ones are deleted.
    public let maxArchivedCartsPerScope: Int?
    
    /// Delete non-active carts older than these thresholds (in days), per status.
    /// Uses `updatedAt` for age evaluation.
    public let deleteExpiredOlderThanDays: Int?
    public let deleteCancelledOlderThanDays: Int?
    public let deleteCheckedOutOlderThanDays: Int?
    
    public init(
        maxArchivedCartsPerScope: Int? = 20,
        deleteExpiredOlderThanDays: Int? = 7,
        deleteCancelledOlderThanDays: Int? = 30,
        deleteCheckedOutOlderThanDays: Int? = nil
    ) {
        self.maxArchivedCartsPerScope = maxArchivedCartsPerScope
        self.deleteExpiredOlderThanDays = deleteExpiredOlderThanDays
        self.deleteCancelledOlderThanDays = deleteCancelledOlderThanDays
        self.deleteCheckedOutOlderThanDays = deleteCheckedOutOlderThanDays
    }
}
