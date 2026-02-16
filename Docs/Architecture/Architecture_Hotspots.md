# CartKit Architecture Hotspots (Phase 1 Baseline)

Date: 2026-02-16
Purpose: Identify high-impact areas to monitor while refactoring toward 2.0.0.

## Hotspot 1: `CartStore` Contract Breadth

- Location: `Sources/CartKitCore/Domain/Ports/CartStore.swift`
- Why high impact:
  - This is the central persistence port used across core and adapters.
  - Changes to this contract propagate to all storage implementations and factories.
- Risk during refactor:
  - Breaking adapter parity or cross-backend migration behavior.

## Hotspot 2: `CartManager` Orchestration Density

- Location: `Sources/CartKitCore/Application/CartManager.swift` and helper extensions.
- Why high impact:
  - `CartManager` coordinates lifecycle, pricing, validation, events, and migration-related flows.
  - Logic changes can affect multiple user-visible behaviors at once.
- Risk during refactor:
  - Behavioral regressions in status transitions, active-cart invariants, and event emission order.

## Hotspot 3: Adapter Query Semantics Consistency

- Locations:
  - `Sources/CartKitTestingSupport/InMemoryCartStore.swift`
  - `Sources/CartKitStorageCoreData/CartStore/CoreDataCartStore+CartStore.swift`
  - `Sources/CartKitStorageSwiftData/Store/SwiftDataCartStore.swift`
- Why high impact:
  - Query semantics (profile/session/status/sort/limit) must be identical across adapters.
- Risk during refactor:
  - Silent divergence across backends despite passing isolated tests.

## Hotspot 4: Migration Wiring and State

- Locations:
  - `Sources/CartKit/Factories/CartStoreFactory.swift`
  - `Sources/CartKit/Migrations/Core/CartStoreMigrationRunner.swift`
  - `Sources/CartKit/Migrations/Backends/CartStoreCrossBackendMigrator.swift`
- Why high impact:
  - Migration policy and backend selection are composition-critical and easy to regress.
- Risk during refactor:
  - Incorrect skip/run conditions, duplicate migration, or fallback behavior drift.

## Guardrails for Phase Work

1. Keep shared contract tests green across all adapters before merging behavior changes.
2. Treat `CartStore` signature changes as explicit migration events.
3. Validate event ordering and active-cart invariants in `CartManager` tests after decomposition.
4. Update migration docs/tests with any policy or wiring changes.
