# ADR-0001: Separate Cart Snapshot Reading from CartStore

- Status: Accepted
- Date: 2026-02-17

## Context

`CartStore` originally mixed app-facing cart operations and migration snapshot behavior (`fetchAllCarts`-style use). This broadened the core persistence contract and forced adapters to expose migration concerns through the same interface used by runtime cart flows.

## Decision

Introduce a separate snapshot-reading contract:

- `CartStore`: runtime CRUD/query operations.
- `CartStoreSnapshotReadable`: migration/snapshot reads.

Migration orchestration and cross-backend migrators now depend on snapshot-capable stores explicitly where required.

## Consequences

Positive:

- Cleaner interface segregation and stronger Clean Architecture boundaries.
- Runtime call sites depend on a narrower, use-case-driven port.
- Migration code documents its storage requirements explicitly.

Trade-offs:

- Some adapters/factory wiring require type composition (`CartStore & CartStoreSnapshotReadable`) in migration paths.

