# ADR-0003: Enforce Adapter Contract Parity with Explicit CI Quality Gates

- Status: Accepted
- Date: 2026-02-17

## Context

Adapter behavior parity (InMemory/CoreData/SwiftData) is critical for query semantics and migration safety. Historically, adapter tests were duplicated and CI did not explicitly isolate contract checks nor execute SwiftData adapter tests in iOS runtime context.

## Decision

Adopt shared contract checks and explicit CI gates:

- Shared suite:
  - `CartStoreContractSuite` in `CartKitTestingSupport`.
- Adapter wrappers:
  - InMemory, CoreData, and SwiftData adapter test targets run the same contract assertions.
- CI gates:
  - Coverage quality gate (line coverage >= 80%).
  - Dedicated contract gate (InMemory/CoreData + domain policy tests).
  - iOS SwiftData contract-test lane via `xcodebuild test`.

## Consequences

Positive:

- Stronger anti-regression coverage for adapter semantics.
- Reduced duplicate test logic and easier parity maintenance.
- CI now protects contract behavior and SwiftData runtime context explicitly.

Trade-offs:

- Additional CI runtime and maintenance overhead.
- iOS simulator availability in CI becomes a dependency for full gate execution.

