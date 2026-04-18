# Anti-Patterns

## First Principle

Most pattern mistakes come from solving imaginary future complexity instead of current design pressure.

## Common Anti-Patterns

### God Object

Symptoms:
- One type owns too much state, too many responsibilities, or too many collaborators
- Changes in unrelated features touch the same file

Better move:
- Split by responsibility and change pressure, not by arbitrary layers

### Singleton As Global State

Symptoms:
- Hidden dependencies
- Order-dependent tests
- Hard-to-reason shared mutable state

Better move:
- Use explicit dependency injection and a clear composition root

### Service Locator

Symptoms:
- Dependencies are fetched implicitly instead of declared
- APIs look simple but hide runtime coupling

Better move:
- Pass dependencies explicitly

### Inheritance For Reuse

Symptoms:
- Deep class hierarchies
- Base classes with optional hooks and fragile assumptions
- Subclasses overriding behavior in surprising ways

Better move:
- Prefer composition, decorators, and protocol or interface boundaries

### Premature Abstraction

Symptoms:
- Interface exists before there are multiple real implementations
- Factory or strategy added for a single concrete type
- Extra indirection without removing any instability

Better move:
- Duplicate a little until the true abstraction is obvious

### Boolean-Flag APIs

Symptoms:
- Methods like `save(force: true, notify: false, async: true)`
- Behavior matrix grows combinatorially

Better move:
- Split intent into separate commands, strategies, or types

### Boolean Soup State

Symptoms:
- Multiple flags describe one lifecycle, such as connecting, connected, syncing, streaming, and retrying
- Impossible combinations appear and special cases keep multiplying

Better move:
- Use a state enum or state machine with explicit transitions

### Stringly Typed Routing

Symptoms:
- Raw strings and prefix checks decide behavior across the codebase
- Renames silently break routing
- Validation happens late, after dispatch has already started

Better move:
- Keep strings at the boundary, then convert into typed commands, actions, or registered capabilities

### Pass-Through Repository Or Facade

Symptoms:
- Wrapper exposes almost every method of the underlying dependency
- Abstraction adds no domain language or policy

Better move:
- Keep the boundary only if it creates a simpler, more stable interface

### God Coordinator

Symptoms:
- One service owns transport, parsing, retry policy, state mutation, side effects, and UI notifications
- Unrelated changes collect in the same file because it is the only place that "knows how the app works"

Better move:
- Split by lifecycle ownership and responsibility, then add a facade only at the product boundary

### Leaky Transport Abstraction

Symptoms:
- UI or feature code knows about WebSocket frames, MCP naming, relay quirks, or raw payload details
- Transport concerns leak upward into unrelated feature logic

Better move:
- Use adapters and facades so transport details stop at the edge

### Over-Abstracted Tool Layer

Symptoms:
- Simple manifest loading or command dispatch is wrapped in several generic abstractions
- More code exists to describe a tool than to run it
- The abstraction adds no policy, validation, or portability benefit

Better move:
- Keep the registry thin until there is real complexity to isolate

### Over-Patterned UI State

Symptoms:
- Tiny screens with heavy MVVM or reducer scaffolding and little payoff
- State scattered across many wrappers for simple view logic

Better move:
- Keep state local until coordination complexity is real

## Pattern Pressure Checks

Before adding a pattern, ask:
- Is there a repeated decision or unstable dependency to isolate?
- Do we already have two or more real behaviors, not hypothetical ones?
- Is the new abstraction smaller and clearer than the branching it replaces?
- Would a future refactor be easier because of this pattern, or just more indirect?

If those answers are weak, keep the code simpler.

## Red Flags In Review

- "We might need this later"
- "This is more scalable" without a specific scaling pressure
- Interfaces with one implementation and no plausible second one
- Factories that just call a single initializer
- Repositories that simply rename ORM methods
- Event systems where direct calls would be clearer
