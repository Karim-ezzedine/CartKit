# ADR-0002: Keep CartManager as Facade and Move Rules to Domain Policies

- Status: Accepted
- Date: 2026-02-17

## Context

`CartManager` is the public SDK facade and coordinates lifecycle, pricing, validation, and events. As behavior expanded, orchestration logic risked becoming the single owner of business rules.

## Decision

Retain `CartManager` as the single public facade while extracting:

- Use-case collaborators:
  - `CartDiscoveryService`
  - `CartPricingOrchestrator`
- Domain rule policies:
  - `ActiveCartGroupPolicy`
  - `CartStatusTransitionPolicy`
  - `CartStatus` transition helpers (`canTransition`, `isActive`, `isArchived`)

`CartManager` delegates rule decisions to these collaborators/policies and focuses on coordination and side effects (persistence/events/analytics).

## Consequences

Positive:

- Better SRP for facade internals.
- Rule logic has a clearer domain home and single source of truth.
- Easier targeted testing for rules vs orchestration.

Trade-offs:

- More internal types to navigate.
- Clear naming and placement conventions are required to prevent fragmentation.

