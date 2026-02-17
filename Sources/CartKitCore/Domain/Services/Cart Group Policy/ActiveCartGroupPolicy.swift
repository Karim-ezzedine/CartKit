/// Encapsulates shared rules for active cart-group processing.
///
/// A "cart group" here means active carts across stores for one
/// `(profileID, sessionID)` scope.
struct ActiveCartGroupPolicy {

    /// Returns carts eligible for group operations.
    ///
    /// - Parameters:
    ///   - carts: Source carts in the group scope.
    ///   - includeEmptyCarts: Whether carts with no items are eligible.
    /// - Returns: Eligible carts for pricing/validation flows.
    func eligibleCarts(
        from carts: [Cart],
        includeEmptyCarts: Bool
    ) -> [Cart] {
        includeEmptyCarts ? carts : carts.filter { !$0.items.isEmpty }
    }

    /// Returns store identifiers that appear more than once.
    ///
    /// - Parameter carts: Carts to inspect.
    /// - Returns: Store IDs with duplicate active carts in the same group.
    func duplicateStoreIDs(in carts: [Cart]) -> Set<StoreID> {
        var seen = Set<StoreID>()
        var duplicates = Set<StoreID>()

        for cart in carts {
            if !seen.insert(cart.storeID).inserted {
                duplicates.insert(cart.storeID)
            }
        }

        return duplicates
    }
}
