# Design Patterns

## How To Use This Reference

- Start from the pressure, not the pattern name.
- Prefer composition over inheritance.
- Add a pattern only when it removes repeated branching, isolates a volatile dependency, or makes a boundary explicit.
- If one simple type solves the problem cleanly, do not add a pattern just for vocabulary.

## Quick Selection

| Problem shape | Likely pattern | Why |
|---|---|---|
| Same task needs swappable behavior | Strategy | Move behavior variation behind one interface |
| Object creation is conditional or multi-step | Factory or Builder | Keep callers from knowing construction details |
| Existing API does not match the API you need | Adapter | Translate one interface into another |
| A subsystem is too noisy or wide | Facade | Expose a smaller, task-focused surface |
| Need to add behavior around an existing object | Decorator | Layer behavior without subclass explosion |
| Behavior changes by lifecycle or mode | State | Replace large state conditionals with explicit states |
| Need to queue, log, retry, or undo actions | Command | Represent work as data |
| One thing changes and many listeners react | Observer | Decouple the source from dependents |
| Lifecycle transitions are as important as behavior | State machine | Make valid states and transitions explicit |
| Persistence details keep leaking upward | Repository | Give domain code a stable storage boundary |
| Construction and wiring are spreading everywhere | Dependency Injection | Centralize dependency assembly |
| Capabilities are declared and looked up dynamically | Registry or plugin | Separate registration from execution |
| Core logic must outlive transport or platform changes | Ports and adapters | Keep domain stable while edges vary |
| Async events keep racing on shared state | Ownership boundary or reducer | Give mutations one clear home |
| UI state and rendering logic are entangled | MVC, MVVM, reducer-style state | Separate view, state, and effects |

## Core Patterns

### Strategy

Use when behavior varies independently from the caller.

Good fit:
- Pricing rules
- Sort and ranking policies
- Retry or backoff policies
- Encoding or serialization choices

Avoid when:
- There is only one real behavior
- The variation is a single branch with no expected growth

### Factory And Builder

Use when construction is conditional, multi-step, or must hide concrete types.

Good fit:
- Choosing implementation from config or environment
- Creating families of related objects
- Building complex request objects

Avoid when:
- Construction is a single initializer with obvious parameters

### Adapter

Use when an external dependency or legacy API has the wrong shape for your codebase.

Good fit:
- Wrapping third-party SDKs
- Converting transport DTOs into domain types
- Bridging old and new interfaces during migration

Avoid when:
- You fully control both sides and can just change one interface

### Facade

Use when callers are forced to coordinate too many low-level objects or steps.

Good fit:
- Payment flow orchestrators
- File import pipelines
- Multi-service feature entry points

Avoid when:
- The facade just mirrors every method from the subsystem

### Decorator

Use when behavior should be layered orthogonally.

Good fit:
- Logging
- Metrics
- Authorization
- Caching

Prefer this over inheritance when combinations of behavior would otherwise create subclass explosion.

### Observer

Use when one source emits changes and multiple consumers react.

Good fit:
- UI updates from state changes
- Event subscribers
- Cache invalidation listeners

Be careful with:
- Hidden control flow
- Fan-out side effects
- Subscription lifecycle leaks

### State

Use when behavior meaningfully changes by mode or lifecycle stage.

Good fit:
- Payment status transitions
- Workflow states
- Connection lifecycle
- UI editor modes

Prefer this over large boolean matrices and nested state conditionals.

### State Machine

Use when transitions matter as much as the current state.

Good fit:
- Connection lifecycle with reconnecting, syncing, live, and failed modes
- Multi-step deployment or setup flows
- Streaming workflows that can resume, cancel, or retry

Prefer this over several independent booleans that can drift into impossible combinations.

### Command

Use when operations need to be stored, retried, logged, scheduled, or undone.

Good fit:
- Background jobs
- Undo stacks
- Action queues
- Workflow steps

### Repository

Use when domain logic should not know query details or persistence plumbing.

Good fit:
- Domain services that should work across storage implementations
- Tests that need a clean storage seam
- Codebases where SQL or transport code is leaking everywhere

Avoid when:
- The repository becomes a vague pass-through over every possible query

### Dependency Injection

Use when dependency construction is spreading or hidden global state is making testing difficult.

Good fit:
- App composition roots
- Service graphs
- Replacing environment-specific implementations

Avoid when:
- DI turns into a framework-shaped ceremony for a tiny object graph

### Registry Or Plugin

Use when capabilities are declared, discovered, and invoked by name.

Good fit:
- MCP tool manifests
- Slash command registries
- Feature modules loaded from configuration

Be careful with:
- Stringly typed lookups
- Duplicate names
- Registries that become global junk drawers

### Ports And Adapters

Use when core logic should not care whether work is done by one platform, transport, or provider versus another.

Good fit:
- iOS app talking to a Mac agent or Linux relay
- Swappable transport layers such as local WebSocket, tunnel, or mock transport
- External APIs and SDKs that should stay at the system edge

Keep domain language inward. Keep transport and provider translation at the boundary.

### Ownership Boundary Or Actor

Use when an async system needs one clear owner for mutable state.

Good fit:
- WebSocket connection state
- Streaming message assembly
- Conversation mutation and history sync

Prefer one owner per mutable state cluster instead of letting many services mutate the same state opportunistically.

### Retry, Backoff, And Circuit Breaker

Use when failure policy is repeating across unstable boundaries.

Good fit:
- Reconnecting sockets
- Retrying transient relay or API failures
- Protecting the app from hammering a failing dependency

Be careful with:
- Retrying non-idempotent actions blindly
- Hiding persistent failures behind endless retries
- Spreading retry policy ad hoc across callers

## Architecture Patterns Often Confused With GoF Patterns

### MVC

Good default when view, controller, and model responsibilities are still simple.

### MVVM

Good when presentation state and derived UI state need a stable home separate from the view.

### Reducer Or Unidirectional State

Good when many events change shared state and you want deterministic updates, tracing, and testability.

### Layered Or Hexagonal Boundaries

Good when transport, domain, and infrastructure responsibilities keep bleeding together.

### Registry-Driven Capability Systems

Good when tools, commands, or handlers are authored independently but exposed through one server or app boundary.

## Selection Heuristics

Ask these before choosing a pattern:
- What changes independently?
- Where is the branching or duplication today?
- Does this pattern remove a real coordination problem or just rename it?
- Will the next engineer understand the abstraction faster than the old code?
- Can composition solve this without adding a new type hierarchy?
