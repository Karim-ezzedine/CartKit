public extension CartManager {
    // MARK: - Item operations
    
    /// Adds a new item to the given cart.
    ///
    /// - Returns: A `CartUpdateResult` describing the updated cart and the item
    ///            that was added.
    func addItem(
        to cartID: CartID,
        item: CartItem
    ) async throws -> CartUpdateResult {
        
        var cart = try await loadMutableCart(for: cartID)
        try await validateItemChange(in: cart, item: item)
        
        cart.items.append(item)
        
        let (cartToPersist, conflicts) = try await detectAndResolveCatalogConflictsIfNeeded(for: cart)
        let updatedCart = try await saveCartAfterMutation(cartToPersist)
        
        config.analyticsSink.itemAdded(item, in: updatedCart)
        
        return CartUpdateResult(
            cart: updatedCart,
            removedItems: [],
            changedItems: [item],
            conflicts: conflicts
        )
    }
    
    /// Updates an existing item in the given cart.
    ///
    /// Matching is done by `CartItem.id`.
    /// - Returns: A `CartUpdateResult` describing the updated cart and the item
    ///            that was changed.
    func updateItem(
        in cartID: CartID,
        item updatedItem: CartItem
    ) async throws -> CartUpdateResult {
        
        var cart = try await loadMutableCart(for: cartID)
        
        guard let index = cart.items.firstIndex(where: { $0.id == updatedItem.id }) else {
            throw CartError.conflict(reason: "Item not found in cart")
        }
        
        try await validateItemChange(in: cart, item: updatedItem)
        
        cart.items[index] = updatedItem
        
        let (cartToPersist, conflicts) = try await detectAndResolveCatalogConflictsIfNeeded(for: cart)
        let updatedCart = try await saveCartAfterMutation(cartToPersist)
        
        config.analyticsSink.itemUpdated(updatedItem, in: updatedCart)
        
        return CartUpdateResult(
            cart: updatedCart,
            removedItems: [],
            changedItems: [updatedItem],
            conflicts: conflicts
        )
    }
    
    /// Removes an item from the given cart by its identifier.
    ///
    /// - Returns: A `CartUpdateResult` describing the updated cart and the item
    ///            that was removed.
    func removeItem(
        from cartID: CartID,
        itemID: CartItemID
    ) async throws -> CartUpdateResult {
        
        var cart = try await loadMutableCart(for: cartID)
        
        guard let index = cart.items.firstIndex(where: { $0.id == itemID }) else {
            throw CartError.conflict(reason: "Item not found in cart")
        }
        
        let removedItem = cart.items.remove(at: index)
        
        let (cartToPersist, conflicts) = try await detectAndResolveCatalogConflictsIfNeeded(for: cart)
        let updatedCart = try await saveCartAfterMutation(cartToPersist)
        
        config.analyticsSink.itemRemoved(itemId: itemID, from: updatedCart)
        
        return CartUpdateResult(
            cart: updatedCart,
            removedItems: [removedItem],
            changedItems: [],
            conflicts: conflicts
        )
    }
}
