import Foundation

public extension CartManager {
    
    // MARK: - Retention Strategy
    
    /// Controls how `maxArchivedCartsPerScope` is applied when cleaning up archived carts.
    ///
    /// - `wholeInput`: caps archived carts for the entire fetched set (single scope).
    /// - `perStore`: caps archived carts independently per `storeID` (group scope across stores).
    private enum ArchivedRetentionScope {
        /// Keep at most N archived carts for the entire input set.
        case wholeInput
        
        /// Keep at most N archived carts per `storeID`.
        case perStore
    }
    
    // MARK: - Lifecycle / Cleanup
    
    /// Cleans up non-active carts for a **single store scope** based on the provided policy.
    ///
    /// Behavior:
    /// - Never deletes `.active` carts.
    /// - Applies time-based deletion per status (using `updatedAt`).
    /// - Applies `maxArchivedCartsPerScope` across the fetched scope (most-recent are kept).
    /// - Scope is enforced as `(storeID + profileID? + sessionID?)`.
    ///
    /// Notes:
    /// - When `sessionID == nil`, cleanup is performed for **sessionless carts only**
    ///   (mapped to `CartQuery.SessionFilter.sessionless`). It will not affect session-based carts.
    func cleanupCarts(
        storeID: StoreID,
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID? = nil,
        policy: CartLifecyclePolicy,
        now: Date = Date()
    ) async throws -> CartCleanupResult {
        
        let sessionFilter: CartQuery.SessionFilter =
        sessionID.map { .session($0) } ?? .sessionless

        let all = try await discoveryService.carts(
            storeID: storeID,
            profileID: profileID,
            session: sessionFilter,
            statuses: nil,
            sort: .updatedAtDescending,
            limit: nil
        )
        
        let toDelete = computeCartsToDelete(
            from: all,
            policy: policy,
            now: now,
            retentionScope: .wholeInput
        )
        
        let result = try await deleteCarts(toDelete)
        
        config.logger.log(
            "Cleanup completed:\nstore=\(storeID.rawValue),\nprofile=\(profileID?.rawValue ?? "guest"),\ndeleted=\(result.deletedCartIDs.count),\nsessionID=\(sessionID?.rawValue ?? "nil")"
        )
        
        return result
    }
    
    /// Cleans up non-active carts for a **session group** across all stores based on the provided policy.
    ///
    /// Behavior:
    /// - Never deletes `.active` carts.
    /// - Applies time-based deletion per status (using `updatedAt`).
    /// - Applies `maxArchivedCartsPerScope` **per store** within the group
    ///   (so each `storeID` retains up to N archived carts).
    /// - Scope is enforced as `(profileID + sessionID)` across stores.
    ///
    /// Notes:
    /// - When `sessionID == nil`, cleanup is performed for **sessionless carts only**
    ///   (mapped to `CartQuery.SessionFilter.sessionless`). It will not affect session-based carts.
    func cleanupCartGroup(
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID?,
        policy: CartLifecyclePolicy,
        now: Date = Date()
    ) async throws -> CartCleanupResult {
        
        let sessionFilter: CartQuery.SessionFilter =
        sessionID.map { .session($0) } ?? .sessionless

        let all = try await discoveryService.carts(
            storeID: nil,
            profileID: profileID,
            session: sessionFilter,
            statuses: nil,
            sort: .updatedAtDescending,
            limit: nil
        )
        
        let toDelete = computeCartsToDelete(
            from: all,
            policy: policy,
            now: now,
            retentionScope: .perStore
        )
        
        let result = try await deleteCarts(toDelete)
        
        config.logger.log(
            "Group cleanup completed:\nprofile=\(profileID?.rawValue ?? "guest"),\nsessionID=\(sessionID?.rawValue ?? "nil"),\ndeleted=\(result.deletedCartIDs.count)"
        )
        
        return result
    }
    
    // MARK: - Internals
    
    /// Computes the set of cart IDs to delete based on lifecycle policy rules.
    ///
    /// Steps:
    /// 1) Excludes `.active` carts (never deleted).
    /// 2) Applies time-based deletion per status using `updatedAt`.
    /// 3) Applies `maxArchivedCartsPerScope` after time-based filtering:
    ///    - `.wholeInput`: caps archived carts across the whole input.
    ///    - `.perStore`: caps archived carts per `storeID`.
    ///
    /// - Returns: IDs of carts that should be deleted.
    private func computeCartsToDelete(
        from carts: [Cart],
        policy: CartLifecyclePolicy,
        now: Date,
        retentionScope: ArchivedRetentionScope
    ) -> Set<CartID> {
        
        // Active carts are never deleted.
        let nonActive = carts.filter { $0.status.isArchived }
        
        var toDelete = Set<CartID>()
        
        func isOlderThanDays(_ cart: Cart, _ days: Int) -> Bool {
            guard days >= 0 else { return false }
            let threshold = now.addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
            return cart.updatedAt < threshold
        }
        
        // Time-based deletion
        for cart in nonActive {
            switch cart.status {
            case .expired:
                if let days = policy.deleteExpiredOlderThanDays, isOlderThanDays(cart, days) {
                    toDelete.insert(cart.id)
                }
            case .cancelled:
                if let days = policy.deleteCancelledOlderThanDays, isOlderThanDays(cart, days) {
                    toDelete.insert(cart.id)
                }
            case .checkedOut:
                if let days = policy.deleteCheckedOutOlderThanDays, isOlderThanDays(cart, days) {
                    toDelete.insert(cart.id)
                }
            case .active:
                break
            }
        }
        
        guard let max = policy.maxArchivedCartsPerScope, max >= 0 else {
            return toDelete
        }
        
        let remaining = nonActive.filter { !toDelete.contains($0.id) }
        
        switch retentionScope {
        case .wholeInput:
            let sorted = remaining.sorted { $0.updatedAt > $1.updatedAt }
            if sorted.count > max {
                let overflow = sorted.suffix(sorted.count - max)
                overflow.forEach { toDelete.insert($0.id) }
            }
            
        case .perStore:
            let byStore = Dictionary(grouping: remaining, by: \.storeID)
            for (_, storeCarts) in byStore {
                let sorted = storeCarts.sorted { $0.updatedAt > $1.updatedAt }
                if sorted.count > max {
                    let overflow = sorted.suffix(sorted.count - max)
                    overflow.forEach { toDelete.insert($0.id) }
                }
            }
        }
        
        return toDelete
    }
}
