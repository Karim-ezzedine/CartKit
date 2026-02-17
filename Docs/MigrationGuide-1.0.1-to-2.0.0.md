# CartKit Migration Guide (1.0.1 -> 2.0.0)

## Summary

This guide covers SDK-side migration for the 2.0.0 architecture update.

The major changes are focused on contract clarity, domain policy ownership, and adapter parity hardening.

## What changed

### 1) Cart query profile scope is explicit

`CartQuery` now supports explicit profile filtering with `profile: CartQuery.ProfileFilter`:

- `.any`
- `.guestOnly`
- `.profile(UserProfileID)`

The old initializer with `profileID` was removed during the 2.0.0 refactor in this branch. Call sites should use `profile:` explicitly.

Example:

```swift
let query = CartQuery(
    storeID: nil,
    profile: .any,
    session: .any,
    statuses: [.active],
    sort: .updatedAtDescending
)

let carts = try await cartManager.queryCarts(matching: query)
```

### 2) Global query API on `CartManager`

Use `CartManager.queryCarts(matching:limit:)` for discovery queries.

This keeps callers on the public facade and avoids direct access to storage adapters.

### 3) Adapter parity is enforced by shared contract tests

All adapters now run the same contract behavior checks through `CartStoreContractSuite`.

This includes profile/session/status/sort/limit behavior and scale-oriented query checks.

### 4) Lifecycle transition decisions moved to domain policy

Status transition decisions are centralized in `CartStatusTransitionPolicy` and used by `CartManager`.

## Migration checklist for integrators

1. Replace any `CartQuery(... profileID: ...)` usage with `CartQuery(... profile: ...)`.
2. Replace direct adapter query calls with `cartManager.queryCarts(matching:limit:)` where applicable.
3. Ensure guest query flows use `.guestOnly` and dashboard discovery flows use `.any`.
4. Re-run app-level tests for status transitions and checkout validation.
