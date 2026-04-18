---
name: system-design
description: Architecture reference - core concepts, technologies, system patterns, software design patterns, anti-patterns, and real-world case studies. Use when designing systems, evaluating tradeoffs, choosing technologies, or selecting an appropriate design pattern.
user-invocable: true
metadata:
  icon: server.rack
  aliases: [architecture, sysdesign, infra]
---

# System Design Reference

## Core Concepts

### Networking
- **HTTP**: Request-response, stateless. Default for most APIs.
- **WebSockets**: Bidirectional, persistent. Chat, gaming, collaborative editing.
- **SSE**: Server to client only, over HTTP. Live feeds, notifications. Simpler than WebSockets when you do not need client to server.
- **gRPC**: Binary (protobuf), bidirectional streaming. Service to service.
- **L4 load balancer**: TCP-level, fast, supports persistent connections.
- **L7 load balancer**: HTTP-level, routes by path/header, content-aware.

### API Design
- **REST**: Resource-based, stateless, HTTP verbs. Default for public APIs.
- **GraphQL**: Client specifies exact data shape. Good when clients have diverse data needs.
- **gRPC**: Protobuf, streaming. Best for internal service to service.
- Pagination: cursor-based > offset-based at scale (offset degrades with depth).

### Data Modeling
- **Relational (Postgres)**: Structured data, strong consistency, complex queries, ACID. Default choice.
- **NoSQL**: Flexible schema, horizontal scaling, high write throughput. Choose for specific access patterns, not by default.
- Start normalized, denormalize hot paths only when needed.
- NoSQL does not mean "no relationships". It means different access pattern optimization.

### Caching
- Cache hit ~1ms (Redis) vs 20-50ms (DB). 20-50x speedup.
- **When**: Read-heavy, data does not change often, can tolerate staleness.
- **Invalidation**: Short TTLs, write-through, or accept eventual consistency.
- **Do not cache**: Write-heavy data, frequently changing data, when consistency is critical.

### Sharding
- Split data across servers when single DB hits storage/write/read limits.
- Shard key must match query patterns. Cross-shard queries are expensive.
- Do not shard prematurely. A well-tuned single Postgres handles more than most assume.

### Consistent Hashing
- Modulo hashing: adding 1 server to 10 moves ~90% of data. Consistent hashing moves ~10%.
- Used in: Redis Cluster, Cassandra, DynamoDB, distributed caches.
- Enables elastic scaling without massive data migrations.

### CAP Theorem
Network partitions are inevitable, so you choose between consistency and availability.
- **Strong consistency**: Inventory, banking, booking (staleness = business harm).
- **Eventual consistency**: Social feeds, recommendations, analytics (staleness is tolerable).
- Most real systems mix both within the same application.

### Latency Numbers
- Memory: nanoseconds. SSD: microseconds. Network (local): 1-10ms. Cross-continent: 10-100ms.
- Single Postgres handles terabytes before you need sharding.

---

## Key Technologies

### Databases
| Tech | Best For | Tradeoff |
|------|----------|----------|
| **PostgreSQL** | Default. ACID, joins, complex queries | Vertical scaling limits |
| **Cassandra** | High write throughput, time-series, append-heavy | No joins, eventual consistency, limited queries |
| **DynamoDB** | Key-value at scale, predictable latency, serverless | Expensive at scale, limited query patterns, vendor lock-in |
| **MongoDB** | Flexible schema, document model, prototyping | Weaker consistency, slow joins |

### Search & Indexing
| Tech | Best For | Tradeoff |
|------|----------|----------|
| **Elasticsearch** | Full-text search, inverted indexes, log analytics | Operational complexity, not a primary DB |

### Caching & In-Memory
| Tech | Best For | Tradeoff |
|------|----------|----------|
| **Redis** | Caching, pub/sub, rate limiting, leaderboards, session store | Data must fit in memory, persistence is secondary |

### Messaging & Streaming
| Tech | Best For | Tradeoff |
|------|----------|----------|
| **Kafka** | Event streaming, log-based messaging, replay, high throughput | Operational complexity, higher latency (>500ms) |
| **SQS** | Simple queue, decoupling services, fully managed | No replay, limited ordering |
| **Flink** | Real-time stream processing, windowed aggregations | Complex to operate |

### Storage
| Tech | Best For | Tradeoff |
|------|----------|----------|
| **S3/GCS** | Large blobs (images, video, files), cheap at scale | Higher latency, needs separate metadata store |

### Infrastructure
| Tech | Best For | Tradeoff |
|------|----------|----------|
| **API Gateway** | Centralized auth, rate limiting, routing | Single point of failure, added latency |
| **CDN** | Static assets, video segments, global distribution | Cache invalidation, cost at high bandwidth |
| **ZooKeeper** | Leader election, distributed coordination, config | Operational burden, not for high-throughput data |

### Analytics
| Tech | Best For | Tradeoff |
|------|----------|----------|
| **ClickHouse/Druid** | OLAP, real-time analytics on large datasets | Not for transactional workloads |
| **Spark** | Batch processing, large-scale data pipelines | High latency, not real-time |

---

## Software Design Patterns

Use this section when the question is about code structure rather than distributed systems.

### How To Use This Reference
- Start from the pressure, not the pattern name.
- Prefer composition over inheritance.
- Add a pattern only when it removes repeated branching, isolates a volatile dependency, or makes a boundary explicit.
- If one simple type solves the problem cleanly, do not add a pattern just for vocabulary.
- Start from the problem shape first. Prefer the simplest solution that isolates the change pressure without introducing speculative abstraction.

### Quick Selection

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

### Core Patterns

#### Strategy

Use when behavior varies independently from the caller.

Good fit:
- Pricing rules
- Sort and ranking policies
- Retry or backoff policies
- Encoding or serialization choices

Avoid when:
- There is only one real behavior
- The variation is a single branch with no expected growth

#### Factory And Builder

Use when construction is conditional, multi-step, or must hide concrete types.

Good fit:
- Choosing implementation from config or environment
- Creating families of related objects
- Building complex request objects

Avoid when:
- Construction is a single initializer with obvious parameters

#### Adapter

Use when an external dependency or legacy API has the wrong shape for your codebase.

Good fit:
- Wrapping third-party SDKs
- Converting transport DTOs into domain types
- Bridging old and new interfaces during migration

Avoid when:
- You fully control both sides and can just change one interface

#### Facade

Use when callers are forced to coordinate too many low-level objects or steps.

Good fit:
- Payment flow orchestrators
- File import pipelines
- Multi-service feature entry points

Avoid when:
- The facade just mirrors every method from the subsystem

#### Decorator

Use when behavior should be layered orthogonally.

Good fit:
- Logging
- Metrics
- Authorization
- Caching

Prefer this over inheritance when combinations of behavior would otherwise create subclass explosion.

#### Observer

Use when one source emits changes and multiple consumers react.

Good fit:
- UI updates from state changes
- Event subscribers
- Cache invalidation listeners

Be careful with:
- Hidden control flow
- Fan-out side effects
- Subscription lifecycle leaks

#### State

Use when behavior meaningfully changes by mode or lifecycle stage.

Good fit:
- Payment status transitions
- Workflow states
- Connection lifecycle
- UI editor modes

Prefer this over large boolean matrices and nested state conditionals.

#### State Machine

Use when transitions matter as much as the current state.

Good fit:
- Connection lifecycle with reconnecting, syncing, live, and failed modes
- Multi-step deployment or setup flows
- Streaming workflows that can resume, cancel, or retry

Prefer this over several independent booleans that can drift into impossible combinations.

#### Command

Use when operations need to be stored, retried, logged, scheduled, or undone.

Good fit:
- Background jobs
- Undo stacks
- Action queues
- Workflow steps

#### Repository

Use when domain logic should not know query details or persistence plumbing.

Good fit:
- Domain services that should work across storage implementations
- Tests that need a clean storage seam
- Codebases where SQL or transport code is leaking everywhere

Avoid when:
- The repository becomes a vague pass-through over every possible query

#### Dependency Injection

Use when dependency construction is spreading or hidden global state is making testing difficult.

Good fit:
- App composition roots
- Service graphs
- Replacing environment-specific implementations

Avoid when:
- DI turns into framework-shaped ceremony for a tiny object graph

#### Registry Or Plugin

Use when capabilities are declared, discovered, and invoked by name.

Good fit:
- MCP tool manifests
- Slash command registries
- Feature modules loaded from configuration

Be careful with:
- Stringly typed lookups
- Duplicate names
- Registries that become global junk drawers

#### Ports And Adapters

Use when core logic should not care whether work is done by one platform, transport, or provider versus another.

Good fit:
- iOS app talking to a Mac agent or Linux relay
- Swappable transport layers such as local WebSocket, tunnel, or mock transport
- External APIs and SDKs that should stay at the system edge

Keep domain language inward. Keep transport and provider translation at the boundary.

#### Ownership Boundary Or Actor

Use when an async system needs one clear owner for mutable state.

Good fit:
- WebSocket connection state
- Streaming message assembly
- Conversation mutation and history sync

Prefer one owner per mutable state cluster instead of letting many services mutate the same state opportunistically.

#### Retry, Backoff, And Circuit Breaker

Use when failure policy is repeating across unstable boundaries.

Good fit:
- Reconnecting sockets
- Retrying transient relay or API failures
- Protecting the app from hammering a failing dependency

Be careful with:
- Retrying non-idempotent actions blindly
- Hiding persistent failures behind endless retries
- Spreading retry policy ad hoc across callers

### Architecture Patterns Often Confused With GoF Patterns

#### MVC

Good default when view, controller, and model responsibilities are still simple.

#### MVVM

Good when presentation state and derived UI state need a stable home separate from the view.

#### Reducer Or Unidirectional State

Good when many events change shared state and you want deterministic updates, tracing, and testability.

#### Layered Or Hexagonal Boundaries

Good when transport, domain, and infrastructure responsibilities keep bleeding together.

#### Registry-Driven Capability Systems

Good when tools, commands, or handlers are authored independently but exposed through one server or app boundary.

### Anti-Patterns

#### First Principle

Most pattern mistakes come from solving imaginary future complexity instead of current design pressure.

#### Common Anti-Patterns

##### God Object

Symptoms:
- One type owns too much state, too many responsibilities, or too many collaborators
- Changes in unrelated features touch the same file

Better move:
- Split by responsibility and change pressure, not by arbitrary layers

##### Singleton As Global State

Symptoms:
- Hidden dependencies
- Order-dependent tests
- Hard-to-reason shared mutable state

Better move:
- Use explicit dependency injection and a clear composition root

##### Service Locator

Symptoms:
- Dependencies are fetched implicitly instead of declared
- APIs look simple but hide runtime coupling

Better move:
- Pass dependencies explicitly

##### Inheritance For Reuse

Symptoms:
- Deep class hierarchies
- Base classes with optional hooks and fragile assumptions
- Subclasses overriding behavior in surprising ways

Better move:
- Prefer composition, decorators, and protocol or interface boundaries

##### Premature Abstraction

Symptoms:
- Interface exists before there are multiple real implementations
- Factory or strategy added for a single concrete type
- Extra indirection without removing any instability

Better move:
- Duplicate a little until the true abstraction is obvious

##### Boolean-Flag APIs

Symptoms:
- Methods like `save(force: true, notify: false, async: true)`
- Behavior matrix grows combinatorially

Better move:
- Split intent into separate commands, strategies, or types

##### Boolean Soup State

Symptoms:
- Multiple flags describe one lifecycle, such as connecting, connected, syncing, streaming, and retrying
- Impossible combinations appear and special cases keep multiplying

Better move:
- Use a state enum or state machine with explicit transitions

##### Stringly Typed Routing

Symptoms:
- Raw strings and prefix checks decide behavior across the codebase
- Renames silently break routing
- Validation happens late, after dispatch has already started

Better move:
- Keep strings at the boundary, then convert into typed commands, actions, or registered capabilities

##### Pass-Through Repository Or Facade

Symptoms:
- Wrapper exposes almost every method of the underlying dependency
- Abstraction adds no domain language or policy

Better move:
- Keep the boundary only if it creates a simpler, more stable interface

##### God Coordinator

Symptoms:
- One service owns transport, parsing, retry policy, state mutation, side effects, and UI notifications
- Unrelated changes collect in the same file because it is the only place that "knows how the app works"

Better move:
- Split by lifecycle ownership and responsibility, then add a facade only at the product boundary

##### Leaky Transport Abstraction

Symptoms:
- UI or feature code knows about WebSocket frames, MCP naming, relay quirks, or raw payload details
- Transport concerns leak upward into unrelated feature logic

Better move:
- Use adapters and facades so transport details stop at the edge

##### Over-Abstracted Tool Layer

Symptoms:
- Simple manifest loading or command dispatch is wrapped in several generic abstractions
- More code exists to describe a tool than to run it
- The abstraction adds no policy, validation, or portability benefit

Better move:
- Keep the registry thin until there is real complexity to isolate

##### Over-Patterned UI State

Symptoms:
- Tiny screens with heavy MVVM or reducer scaffolding and little payoff
- State scattered across many wrappers for simple view logic

Better move:
- Keep state local until coordination complexity is real

### Pattern Pressure Checks

Before adding a pattern, ask:
- Is there a repeated decision or unstable dependency to isolate?
- Do we already have two or more real behaviors, not hypothetical ones?
- Is the new abstraction smaller and clearer than the branching it replaces?
- Would a future refactor be easier because of this pattern, or just more indirect?

If those answers are weak, keep the code simpler.

### Red Flags In Review

- "We might need this later"
- "This is more scalable" without a specific scaling pressure
- Interfaces with one implementation and no plausible second one
- Factories that just call a single initializer
- Repositories that simply rename ORM methods
- Event systems where direct calls would be clearer

### Selection Heuristics

Ask these before choosing a pattern:
- What changes independently?
- Where is the branching or duplication today?
- Does this pattern remove a real coordination problem or just rename it?
- Will the next engineer understand the abstraction faster than the old code?
- Can composition solve this without adding a new type hierarchy?

---

## Common System Patterns

### 1. Real-Time Updates
**Problem**: Push live data to clients.
**Approach**: HTTP polling -> SSE for server-push -> WebSockets for bidirectional. Server-side: pub/sub (Redis) or consistent hash ring for stateful connections.
**Insight**: <200ms feels real-time. At extreme volume (live comments), sample the stream. Users experience the vibe, not individual items.

### 2. Long-Running Tasks
**Problem**: Operations taking seconds to minutes (encoding, report generation).
**Approach**: Accept -> return job ID -> queue (Kafka/SQS) -> workers process -> client polls or gets callback.
**Insight**: Do not queue short tasks (<1s). Synchronous is simpler and gives clearer backpressure.

### 3. Contention
**Problem**: Multiple actors competing for same resource (last ticket, auction bid).
**Approach**: DB transactions -> pessimistic locking -> optimistic locking -> distributed locks -> queue-based serialization. Escalate only as needed.
**Insight**: Queue-based serialization (one request at a time per resource) prevents double-booking elegantly.

### 4. Scaling Reads
**Problem**: Read traffic vastly exceeds writes.
**Approach**: Indexing -> denormalization -> read replicas -> Redis cache -> CDN (escalation order).
**Insight**: Cache the hot path aggressively. Most systems are read-heavy.

### 5. Scaling Writes
**Problem**: Single DB cannot handle write throughput.
**Approach**: Write queues for burst absorption -> horizontal sharding -> vertical partitioning -> load shedding.
**Insight**: Partition key is everything. Bad key = hot partitions = worse than no sharding.

### 6. Large Blobs
**Problem**: Files/media routing through app servers creates bottlenecks.
**Approach**: Presigned URLs for direct client to S3 upload/download. CDN for distribution. Metadata in DB, files in blob storage.
**Insight**: Never route large files through your servers. Presigned URLs = zero server load.

### 7. Multi-Step Processes
**Problem**: Workflows across services that must survive failures (order fulfillment, payments).
**Approach**: Orchestration (Temporal, Step Functions) or saga pattern with compensating transactions.
**Insight**: Event sourcing gives audit trail + state reconstruction for free.

### 8. Proximity/Geo
**Problem**: Find nearby entities efficiently.
**Approach**: Geohash or S2 cells for spatial indexing. PostGIS, Redis geo, or Elasticsearch geo-queries.
**Insight**: Below ~100K items, brute-force distance calc on indexed lat/lng works fine.

---

## Study Cases

### Bit.ly (URL Shortener)
**Challenge**: Extreme read-heavy ratio (~1000:1).
**Key**: Base62 encoding. Aggressive Redis caching. URLs rarely change. Optimize read path obsessively.

### Dropbox (File Sync)
**Challenge**: Sync across devices without re-uploading entire files.
**Key**: Chunk files into blocks, SHA-256 hash each. Only sync changed chunks (deduplication). Metadata in DB, chunks in blob storage.

### News Aggregator (Google News)
**Challenge**: Aggregate thousands of sources into personalized feeds.
**Key**: Crawl/ingest from publishers, deduplicate similar stories. Rank by relevance (recency, engagement, user interests). Cursor-based pagination for infinite scroll. Cache precomputed feeds.

### Ticketmaster (Booking)
**Challenge**: Extreme contention, 10K seats, millions of users.
**Key**: Queue-based serialization instead of long DB locks. Virtual waiting room to control inflow. Strong consistency for booking, eventual for browsing.

### Facebook News Feed
**Challenge**: Fan-out, one post must appear in millions of feeds.
**Key**: Hybrid fanout, on-write for normal users (precompute), on-read for celebrities (too many followers). Merge at read time.

### Tinder (Discovery)
**Challenge**: Geo-based discovery with multi-dimensional filtering.
**Key**: Geohash cells for spatial queries. Elasticsearch for compound filters (location + preferences + age). Pre-compute recommendation pools.

### LeetCode (Code Execution)
**Challenge**: Sandboxed execution with queue-based scaling.
**Key**: Docker containers per submission. Queue-based: return job ID, workers pull and execute, report results. Long-running task pattern.

### WhatsApp (Messaging)
**Challenge**: Guaranteed delivery + real-time + offline support.
**Key**: WebSockets with sticky sessions. Cassandra/DynamoDB for messages (high write, simple access: chat ID + time). Redis for presence. Acknowledge immediately, persist async.

### Yelp (Local Search)
**Challenge**: Geo + text search + ranking across millions of businesses.
**Key**: Geohash/quadtree for proximity. Elasticsearch for full-text + geo compound queries. Rank by proximity x rating x review confidence. CDN for images. Handle hotspot areas (Times Square) with sharding/caching.

### Strava (Fitness Tracking)
**Challenge**: GPS trace storage, segment matching, leaderboards.
**Key**: Store GPS traces as time-series. Match traces against predefined segments (road/trail stretches). Leaderboards per segment, sorted set in Redis or materialized view. Batch-process new activities against all matching segments.

### Rate Limiter
**Challenge**: Distributed rate limiting across multiple gateway instances.
**Key**: Token bucket algorithm (burst-friendly). Redis for central state. Lua scripts for atomic read-calculate-update. One Redis key with TTL per bucket.

### Online Auction (eBay)
**Challenge**: Real-time bidding with contention at auction close.
**Key**: Partition by auction ID to reduce contention. Server-side timestamps for bid ordering (do not trust client clocks). Event stream for real-time bid updates via WebSocket/SSE. Optimistic locking, reject bid if current highest changed.

### Facebook Live Comments
**Challenge**: Thousands of comments/sec per stream, millions of viewers.
**Key**: SSE (server-push sufficient). At extreme volume, sample the stream. Availability over consistency. <200ms target.

### Facebook Post Search
**Challenge**: Full-text search at massive scale.
**Key**: Inverted index, map keywords -> document IDs. Cap per-keyword index size (1K-10K). Cold keywords -> blob storage. Rank by relevance + recency + social proximity.

### Price Tracking (CamelCamelCamel)
**Challenge**: Monitor millions of product prices, alert on drops.
**Key**: Distributed scraper pools partitioned by product range. Time-series storage for price history. Threshold-based notifications via queue. Retry with exponential backoff for scraper failures. Dead-letter queue for failed alerts.

### Instagram (Photo Sharing)
**Challenge**: Feed generation + image storage at massive scale.
**Key**: Similar fan-out to Facebook News Feed. Presigned URLs for image upload to S3. CDN for serving. Transcode images to multiple sizes. Stories = ephemeral content with TTL.

### YouTube Top K
**Challenge**: Precisely count top K most-viewed videos across time windows.
**Key**: Streaming aggregation, Kafka -> Flink with windowed counters. Use heap for maintaining top K per window. Multi-granularity: aggregate hourly, roll up to daily/monthly. Batch correction path for accuracy.

### Uber (Ride Matching)
**Challenge**: Real-time location matching at ~2M updates/sec.
**Key**: Geohash spatial indexing. Location Service ingests GPS via Kafka. Match: rider's geohash -> drivers in same + adjacent cells. Redis for ephemeral driver state with aggressive TTL.

### Robinhood (Trading)
**Challenge**: Real-time market data + order execution with strict correctness.
**Key**: Exchange feeds -> normalize -> Kafka pub/sub. In-memory cache for frequently accessed symbols. WebSockets for live price streaming. Orders are synchronous request/response to exchange. Idempotency keys prevent duplicate orders.

### Google Docs (Collaboration)
**Challenge**: Multiple users editing same document simultaneously.
**Key**: Operational Transform (OT). Each edit is an operation (insert/delete at position), server transforms concurrent operations to maintain consistency. WebSockets for real-time sync. Central server as source of truth. CRDTs are an alternative for decentralized/offline-first scenarios.

### Distributed Cache
**Challenge**: Build a cache layer that scales horizontally.
**Key**: Consistent hashing for key distribution across nodes. LRU eviction policy. Hot key mitigation via read replicas across multiple nodes. Cluster topology changes move minimal data. Client-side consistent hash ring for routing.

### YouTube (Video Streaming)
**Challenge**: Upload -> processing -> adaptive streaming globally.
**Key**: Resumable multipart uploads. Post-processing: transcode to multiple resolutions, generate HLS/DASH manifest. CDN edge caching. Separate hot/cold storage tiers.

### Job Scheduler
**Challenge**: Reliable distributed task scheduling (cron + ad-hoc).
**Key**: Jobs stored in DB with schedule metadata. Scheduler service checks for due jobs, enqueues to Kafka/SQS. Workers pull and execute. Decentralized pull model scales better than centralized assignment. Retry with backoff for failures. Execution history for debugging.

### Web Crawler
**Challenge**: Crawl billions of pages without loops or traps.
**Key**: Frontier queue holds URLs to crawl. Check metadata DB to avoid re-crawling. DNS caching. Max depth limit (15-20 hops) for crawler traps. Rate-limit per domain, respect robots.txt.

### Ad Click Aggregator
**Challenge**: High-throughput event ingestion with real-time + batch analytics.
**Key**: Dual path, Kafka -> Flink for real-time, S3 -> Spark for batch correction. OLAP (ClickHouse/Druid) for serving. Idempotency keys prevent double-counting. Salting to mitigate hot-key skew.
