# CartKit

A modular, local multi-cart SDK for iOS apps.

CartKit lets you manage multiple carts per store and per user scope (guest or profile), with pluggable storage (Core Data, SwiftData, or your own) and configurable pricing/validation/promotion / conflict-resolution engines.

**CartKit at a glance**
- Local-first cart management (no networking)
- Supports guest and profile carts
- Multiple carts per store
- Explicit composition and dependency injection
- Pluggable storage and business policies

> **Status:** WIP  
> APIs and behavior may change until v1.0 is tagged.

---

## Requirements

- **iOS:** 15.0+
- **Swift:** 5.9+
- **Xcode:** 15+
- **SwiftData storage:** iOS 17+ (separate target guarded by availability)

---

## Modules

- **CartKit**  
  Umbrella module that re-exports `CartKitCore` with default storage integrations.  
  Suitable for apps that want a simple, batteries-included setup.
  
- **CartKitCore**
  Domain types (`Cart`, `CartItem`, `Money`, `CartTotals`, etc.), `CartManager`, configuration, and extension-point protocols.

- **CartKitStorageCoreData**  
  Core Data `CartStore` implementation (iOS 15+).

- **CartKitStorageSwiftData**  
  SwiftData `CartStore` implementation (iOS 17+; availability guarded).

- **CartKitTestingSupport**  
  Test helpers (in-memory store, fakes/spies) for unit and integration tests.

Most apps import **`CartKitCore`** in feature code and keep storage selection in the composition/DI layer.  
Apps that prefer a simpler setup may import **`CartKit`** instead.

---

## Installation (Swift Package Manager)

### Xcode

1. **File → Add Packages…**
2. Enter the repository URL:
   ```text
    https://github.com/Karim-ezzedine/CartKit
   ```
---

## Configuration & Composition

CartKit is designed around explicit composition at the application boundary.

Applications are expected to assemble a `CartConfiguration` in their dependency-injection or composition layer. This configuration defines how carts behave, where they are stored, and which policies are applied.

> CartKit performs no implicit setup and relies on no global state.
> All behavior is defined through explicit configuration.

### Building a CartConfiguration

**A `CartConfiguration` wires together:**
- Cart storage
- Pricing, validation, and promotion engines
- Catalog conflict handling
- Analytics and logging

The recommended entry point is the asynchronous convenience builder:

`CartConfiguration.configured(...)`

This builder resolves storage, applies safe defaults where appropriate, and returns a fully configured instance ready to be used by `CartManager`.

Composition is intentionally explicit to ensure predictable behavior, testability, and clear ownership of business policies outside the domain.

Tests may bypass this builder and construct CartConfiguration directly.

### Example: wiring CartManager

```swift
import CartKitCore

// In your DI / composition layer:
let configuration = try await CartConfiguration.configured(
    storage: .automatic // .coreData, .swiftData
)

let cartManager = CartManager(configuration: configuration)

```
---

### Choosing configuration options

Configuration decisions generally fall into two categories:

#### Storage choice

Applications select how carts are persisted (Core Data, SwiftData, or a custom implementation).  
Storage selection is performed once at composition time and remains stable for the lifetime of the configuration.

Details are covered in the *Storage selection* section below.

#### Guest vs profile usage

Guest and profile carts do not require separate configurations.

Both use the same configuration and manager; behavior differences are driven by cart scope and identifiers rather than by distinct setups.

---

## Guest vs Profile semantics

CartKit models guest and profile carts using the same domain type.

### Guest carts

A cart is considered a guest cart when:

`profileID == nil`

Guest carts are local-only, not tied to a user account, and can be migrated later when a user authenticates.

There is no separate “guest cart” type. Guest behavior is a semantic interpretation, not a different model.

---

### Profile carts

A cart becomes a profile cart when it is associated with a non-nil `profileID`.

Profile carts follow the same lifecycle rules as guest carts and differ only in ownership and scope.

---

### One-active-cart rule

For a given `(storeID, profileID, sessionID)` scope, only one cart may be active at a time.

This allows multi-store checkout by enabling multiple active carts for the same profile/session
as long as they belong to different stores (each cart remains store-scoped).

This invariant is enforced by `CartManager`, not by storage implementations.

---

### Session groups (multi-store checkout)

CartKit supports a single checkout that may include items fulfilled by multiple stores by introducing a **session group**.

**A session group is identified by `(profileID, sessionID)`:**
- A session group can contain multiple `.active` carts across different stores.
- Each cart remains store-scoped (`Cart.storeID` is a single store).
- Checkout orchestration is done by grouping carts by `sessionID`.

Session groups also have dedicated lifecycle helpers (cleanup across stores) — see *Cart operations → Lifecycle & cleanup*.

To discover what checkout groups currently exist for a user (or guest), use:

- `getActiveCartGroups(profileID:)`

Each group contains `.active` carts only, sorted by recency.

#### Example: creating a multi-store checkout session

```swift
let profileID = UserProfileID("user_123")
let sessionID = CartSessionID("checkout_session_abc") // or CartSessionID.generate()

// Store A active cart in the session group
_ = try await cartManager.setActiveCart(
    storeID: StoreID("store_A"),
    profileID: profileID,
    sessionID: sessionID
)

// Store B active cart in the same session group
_ = try await cartManager.setActiveCart(
    storeID: StoreID("store_B"),
    profileID: profileID,
    sessionID: sessionID
)

// List active groups
let groups = try await cartManager.getActiveCartGroups(profileID: profileID)
```

---

### Guest → profile migration

When a guest authenticates, applications may choose to migrate the active guest cart to a profile cart.

CartKit provides helper APIs to support this flow, while leaving the timing and strategy of migration entirely to the client.

Migration helpers are designed to preserve cart contents and respect active cart invariants without performing implicit destructive actions.

#### Example: migrate guest active cart to a profile cart

```swift
let storeID = StoreID("store_A")
let profileID = UserProfileID("user_123")
let sessionID = CartSessionID("checkout_session_abc")

let migrated = try await cartManager.migrateGuestActiveCart(
    storeID: storeID,
    to: profileID,
    strategy: .move,
    sessionID: sessionID
)
```

---

## Cart operations

This section shows minimal “how-to” examples for the most commonly used `CartManager` APIs:
creating/reading an active cart, mutating items, updating status, and observing events.

### Active cart & discovery

Use `setActiveCart` to ensure a single active cart exists for a given `(storeID, profileID, sessionID)` scope.
Use `getActiveCart` (or `getCart`) to retrieve it later.

```swift
let storeID = StoreID("store_A")
let profileID = UserProfileID("user_123")
let sessionID = CartSessionID("checkout_session_abc") // or CartSessionID.generate()

// Ensure there is an active cart for this scope (creates if missing).
let cart = try await cartManager.setActiveCart(
    storeID: storeID,
    profileID: profileID,
    sessionID: sessionID
)

// Load active cart again (same scope).
let active = try await cartManager.getActiveCart(
    storeID: storeID,
    profileID: profileID,
    sessionID: sessionID
)

// Load by ID (works for any status).
let byID = try await cartManager.getCart(id: cart.id)
```

### Items (add / update / remove)

Item mutations operate on a specific `cartID`.

```swift
let cart = try await cartManager.setActiveCart(
    storeID: StoreID("store_A"),
    profileID: UserProfileID("user_123"),
    sessionID: CartSessionID("checkout_session_abc")
)

let itemID = CartItemID.generate()

// Add
let addResult = try await cartManager.addItem(
    to: cart.id,
    item: CartItem(
        id: itemID,
        productID: "burger",
        quantity: 1,
        unitPrice: Money(amount: 10, currencyCode: "USD"),
        modifiers: [],
        imageURL: nil
    )
)

// Update (by CartItem.id)
let updateResult = try await cartManager.updateItem(
    in: cart.id,
    item: CartItem(
        id: itemID,
        productID: "burger",
        quantity: 2,
        unitPrice: Money(amount: 10, currencyCode: "USD"),
        modifiers: [],
        imageURL: nil
    )
)

// Remove
let removeResult = try await cartManager.removeItem(
    from: cart.id,
    itemID: itemID
)
```

### Status & checkout

`updateStatus` enforces status transition rules. Transitioning to `.checkedOut` validates the cart via the configured `CartValidationEngine`.

```swift
let profileID = UserProfileID("user_123")

let cart = try await cartManager.setActiveCart(
    storeID: StoreID("store_A"),
    profileID: profileID,
    sessionID: CartSessionID("checkout_session_abc")
)

// ...add items...

let checkedOut = try await cartManager.updateStatus(
    for: cart.id,
    to: .checkedOut
)
```

### Observability (events)

CartManager emits events for cart and item mutations, status changes, and active cart changes.

#### UI layer observing cart changes:
```swift
let stream = await cartManager.observeEvents()
     
Task {
    for await event in stream {
         switch event {
         case .cartCreated(let id):
             // Refresh cart list, or load cart by id.
             break
         case .cartUpdated(let id):
             // Refresh cart UI / totals.
             break
         case .cartDeleted(let id):
             // Remove from UI.
             break
         case .activeCartChanged(let storeID, let profileID, let cartID):
             // Update "current cart" state for this scope.
             break
         }
     }
 }
```

#### Combine wrapper (UIKit/SwiftUI projects already using Combine):

```swift
 Task { @MainActor in
     let publisher = await cartManager.eventsPublisher()
     publisher
         .sink { event in
             // Handle event
         }
         .store(in: &cancellables)
 }
```
### Lifecycle & cleanup

CartKit provides cleanup utilities for removing **archived** carts (non-`.active`) based on a `CartLifecyclePolicy`.

**Key rules:**
- `.active` carts are never deleted.
- Archived carts may be deleted by age (per status) and/or capped by retention count.
- Cleanup works either for a **single store scope** or a **session group across stores**.

> Important: when `sessionID == nil`, cleanup targets **sessionless carts only** and will not affect session-based carts.

#### Example: cleanup archived carts for a single store scope

Use `cleanupCarts(storeID:profileID:sessionID:policy:)` to clean archived carts within:
`(storeID + profileID? + sessionID?)`.

```swift
let storeID = StoreID("store_A")
let profileID = UserProfileID("user_123")
let sessionID = CartSessionID("checkout_session_abc")

let policy = CartLifecyclePolicy(
    maxArchivedCartsPerScope: 20,
    deleteExpiredOlderThanDays: 7,
    deleteCancelledOlderThanDays: 30,
    deleteCheckedOutOlderThanDays: nil
)

let result = try await cartManager.cleanupCarts(
    storeID: storeID,
    profileID: profileID,
    sessionID: sessionID,
    policy: policy
)

print("Deleted carts:", result.deletedCartIDs)
```

#### Example: cleanup archived carts for a session group (across stores)

Use `cleanupCartGroup(profileID:sessionID:policy:)` to clean archived carts for a checkout session group:
`(profileID + sessionID)` across **any store**.

Retention (`maxArchivedCartsPerScope`) is applied **per store** within the session group.

```swift
let profileID = UserProfileID("user_123")
let sessionID = CartSessionID("checkout_session_abc")

let policy = CartLifecyclePolicy(
    maxArchivedCartsPerScope: 10,
    deleteExpiredOlderThanDays: 7,
    deleteCancelledOlderThanDays: 30
)

let result = try await cartManager.cleanupCartGroup(
    profileID: profileID,
    sessionID: sessionID,
    policy: policy
)

print("Deleted carts:", result.deletedCartIDs)
```

---

## Storage selection

CartKit does not hardcode a persistence mechanism.

Storage is selected explicitly during configuration and injected into the cart system.

### Using CartStoreFactory

`CartStoreFactory` is responsible for creating a `CartStore` based on a `CartStoragePreference`.

This keeps storage decisions out of the domain layer and avoids platform-specific logic in feature code.

Applications are expected to resolve storage once at composition time.

---

### iOS 15 vs iOS 17 guidance

**CartKit provides two built-in storage implementations:**
- **Core Data**
  - Available on iOS 15 and later
  - Recommended for apps supporting iOS 15 or 16

- **SwiftData**
  - Available on iOS 17 and later
  - Guarded by availability checks
  - Recommended for iOS 17-only applications

SwiftData support lives in a separate module and is never selected implicitly.

For applications supporting multiple OS versions, Core Data remains the safest default.

---

### Custom storage

Applications may provide their own `CartStore` implementation.

Custom storage is useful when an existing system handles persistence, requires custom synchronization, or is intentionally ephemeral.

Custom implementations must respect domain invariants but are otherwise unconstrained.

---

## Engines & extension points

CartKit keeps the domain model stable and exposes variability through explicit extension points (“engines”). This allows applications to adapt policies (pricing, validation, promotions, conflict handling) without forking domain logic or leaking infrastructure concerns into feature code.

**From a Clean Architecture perspective:**
- **Domain/Core:** Entities and engine protocols define *what* must be true.
- **Application:** `CartManager` orchestrates *when* policies are applied and enforces invariants.
- **Infrastructure:** Concrete engine implementations and persistence are injected at composition time.

### What is an “engine” in CartKit?

An engine is a protocol-backed component that encapsulates a specific business policy, such as:

- How totals are computed
- Which items are allowed and under what constraints
- How promotions are applied
- How conflicts should be detected and resolved

Engines are passed into `CartConfiguration`, making behavior explicit, testable, and deterministic.

---

### Pricing

The pricing engine is responsible for computing cart totals based on the cart’s contents.

**Typical responsibilities:**
- Subtotal calculation
- Fee and tax inclusion (if applicable)
- Final total computation

**Pricing is intentionally isolated so applications can:**
- Keep calculations consistent with backend rules
- Swap pricing logic per market or experiment
- Test totals deterministically

#### Checkout totals for a session group

**For session-based checkout, CartKit can compute totals across all active carts in a `(profileID, sessionID)` group:**
- Each store cart is priced independently (store-scoped context).
- Promotions can be provided per store.
- Results include per-store totals and an aggregated total (same-currency assumption).

```swift
let totals = try await cartManager.getTotalsForActiveCartGroup(
    profileID: profileID,
    sessionID: sessionID,
    promotionsByStore: [
        StoreID("store_A"): [.percentageOffCart(0.10)], // 10%
        StoreID("store_B"): [.freeDelivery]
    ]
)

let perStore = totals.perStore
let aggregate = totals.aggregate
```
---

### Validation

The validation engine determines whether the cart is eligible for progression (for example, before checkout).

**Typical responsibilities include:**
- Item-level rules (quantity bounds, required metadata, etc.)
- Cart-level rules (minimum order value, incompatible combinations, etc.)
- Producing structured validation outcomes

Validation is a key boundary: CartKit can manage carts for guests, but applications often require additional rules before checkout (for example, authentication or delivery availability). Those rules belong in the validation policy, not in the domain entities themselves.

#### Validate a session group before checkout

Applications can validate every active store cart in a session group before checkout:

```swift
let validation = try await cartManager.validateBeforeCheckoutForActiveCartGroup(
    profileID: profileID,
    sessionID: sessionID
)

if validation.isValid {
    // Safe to proceed with checkout
} else {
    // Inspect per-store results (which store is blocking checkout)
    let perStore = validation.perStore
}
```
---

### Promotions

Promotions are modeled as policy: how discounts/rewards are discovered, applied, and represented.

**Typical responsibilities include:**
- Applying promo codes
- Automatic offers (buy X get Y, tiered discounts, etc.)
- Updating applied promotions as cart contents change

Promotion behavior varies significantly between products; keeping it behind an engine prevents domain model churn and supports A/B testing and regional rules.

---

### Catalog conflict handling (client responsibility)

**CartKit supports multiple carts and multiple scopes, which introduces the possibility of conflicts when:**
- A product becomes unavailable
- Catalog data changes (price, modifiers, constraints)
- A cart is restored after time has passed
- Two sources propose differing representations for the same item

**CartKit exposes explicit conflict detection and resolution extension points so the client can define the correct business behavior. Examples include:**
- “Remove unavailable items automatically.”
- “Keep items but mark them invalid until the user confirms.”
- “Prefer latest catalog price vs preserve original price.”

This is intentionally client-owned because conflict strategy is product-specific and often UX-driven.

---

### Analytics and logging as extension points

CartKit emits domain-level signals (such as cart changes and lifecycle events) through dedicated sinks.

This keeps:
- Domain logic free from analytics vendors
- Instrumentation consistent and testable
- Event emission deterministic

Applications can plug in their own analytics/logging implementations in the configuration layer without affecting the domain.

---

### Practical guidance

**Recommended defaults:**
- Keep engines lightweight and deterministic.
- Avoid networking inside engines where possible (prefer pre-fetched inputs).
- Treat engines as pure policy objects: given the same input, they should produce the same output.
- For tests, inject fakes/spies to assert orchestration and outcomes.

---

## Testing examples

CartKit is designed to be testable by construction.

All cart behavior is driven through explicit dependencies (such as storage and policies), allowing tests to run deterministically without relying on UI layers or platform persistence.

This section demonstrates a basic cart flow using Swift Testing.

### Testing strategy

Recommended testing principles:

- Interact with carts only through `CartManager`
- Inject test or in-memory `CartStore` implementations
- Rely on default engines unless a test requires custom behavior
- Assert on domain outcomes, not side effects

This approach aligns naturally with test-driven development (TDD).

---

### Example: basic cart flow

The following example demonstrates a simple end-to-end cart scenario:

1. Create a test cart store
2. Build a minimal configuration
3. Set an active cart
4. Add an item
5. Assert on domain state

```swift

import Testing
import CartKitCore
import CartKitTestingSupport

struct CartFlowTests {

    @Test
    func basicCartFlow() async throws {
        // 1. Create a test store
        let store = InMemoryCartStore()

        // 2. Build a minimal configuration
        let configuration = CartConfiguration(
            cartStore: store
        )

        let manager = CartManager(configuration: configuration)

        // 3. Set an active cart (guest)
        let cart = try await manager.setActiveCart(
            storeID: StoreID("store-1"),
            profileID: nil
        )

        // 4. Add an item
        let cartUpdateResult = try await manager.addItem(
            to: cart.id,
            item: CartItem(
                id: CartItemID.generate(),
                productID: "burger",
                quantity: 1,
                unitPrice: Money(amount: 10, currencyCode: "USD"),
                modifiers: [],
                imageURL: nil
            )
        )

        // 5. Assert domain state
        #expect(cartUpdateResult.cart.items.count == 1)
        #expect(cartUpdateResult.cart.status == .active)
    }
}

```
