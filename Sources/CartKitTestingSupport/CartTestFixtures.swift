import Foundation
import CartKitCore

/// Shared demo/preview data for tests and SwiftUI previews.
///
/// These helpers intentionally keep the data simple but realistic:
/// - one guest cart (no profile),
/// - one logged-in cart.
/// Host apps can build on top of this or provide their own fixtures.
public enum CartTestFixtures {

    // MARK: - IDs

    public static let demoStoreID = StoreID(rawValue: "store_demo_1")
    public static let anotherStoreID = StoreID(rawValue: "store_demo_2")
    public static let demoProfileID = UserProfileID(rawValue: "user_demo_1")

    // MARK: - Public factory

    /// Returns a small set of demo carts:
    /// - a guest cart for `demoStoreID` (profileID == nil),
    /// - a logged-in cart for `demoStoreID` (profileID == demoProfileID).
    public static func demoCarts(now: Date = Date()) -> [Cart] {
        [
            guestCart(storeID: demoStoreID, now: now),
            loggedInCart(storeID: demoStoreID, profileID: demoProfileID, now: now)
        ]
    }

    // MARK: - Individual carts

    /// Guest cart (no profile) with a couple of simple items.
    public static func guestCart(
        storeID: StoreID = demoStoreID,
        now: Date = Date()
    ) -> Cart {
        let item1 = CartItem(
            id: CartItemID.generate(),
            productID: "burger_combo",
            quantity: 1,
            unitPrice: Money(amount: 8.99, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        let item2 = CartItem(
            id: CartItemID.generate(),
            productID: "fries_large",
            quantity: 2,
            unitPrice: Money(amount: 2.49, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        return Cart(
            id: CartID.generate(),
            storeID: storeID,
            profileID: nil,
            items: [item1, item2],
            status: .active,
            createdAt: now.addingTimeInterval(-1800), // 30 min ago
            updatedAt: now,
            metadata: ["source": "demo_guest"],
            displayName: "Guest cart",
            context: "Preview/demo",
            storeImageURL: nil
        )
    }

    /// Logged-in cart with a couple of items and a profile attached.
    public static func loggedInCart(
        storeID: StoreID = demoStoreID,
        profileID: UserProfileID = demoProfileID,
        now: Date = Date()
    ) -> Cart {
        let item = CartItem(
            id: CartItemID.generate(),
            productID: "pizza_margherita",
            quantity: 1,
            unitPrice: Money(amount: 12.50, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        return Cart(
            id: CartID.generate(),
            storeID: storeID,
            profileID: profileID,
            items: [item],
            status: .active,
            createdAt: now.addingTimeInterval(-3600), // 1 hour ago
            updatedAt: now,
            metadata: ["source": "demo_logged_in"],
            displayName: "Karim’s cart",
            context: "Preview/demo",
            storeImageURL: nil
        )
    }
}

