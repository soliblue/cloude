---
name: system-design
description: Architecture reference — core concepts, technologies, patterns, and real-world case studies. Use when designing systems, evaluating tradeoffs, or choosing technologies.
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
- **SSE**: Server→client only, over HTTP. Live feeds, notifications. Simpler than WebSockets when you don't need client→server.
- **gRPC**: Binary (protobuf), bidirectional streaming. Service-to-service.
- **L4 load balancer**: TCP-level, fast, supports persistent connections.
- **L7 load balancer**: HTTP-level, routes by path/header, content-aware.

### API Design
- **REST**: Resource-based, stateless, HTTP verbs. Default for public APIs.
- **GraphQL**: Client specifies exact data shape. Good when clients have diverse data needs.
- **gRPC**: Protobuf, streaming. Best for internal service-to-service.
- Pagination: cursor-based > offset-based at scale (offset degrades with depth).

### Data Modeling
- **Relational (Postgres)**: Structured data, strong consistency, complex queries, ACID. Default choice.
- **NoSQL**: Flexible schema, horizontal scaling, high write throughput. Choose for specific access patterns, not by default.
- Start normalized, denormalize hot paths only when needed.
- NoSQL doesn't mean "no relationships" — it means different access pattern optimization.

### Caching
- Cache hit ~1ms (Redis) vs 20-50ms (DB). 20-50x speedup.
- **When**: Read-heavy, data doesn't change often, can tolerate staleness.
- **Invalidation**: Short TTLs, write-through, or accept eventual consistency.
- **Don't cache**: Write-heavy data, frequently changing data, when consistency is critical.

### Sharding
- Split data across servers when single DB hits storage/write/read limits.
- Shard key must match query patterns. Cross-shard queries are expensive.
- Don't shard prematurely — a well-tuned single Postgres handles more than most assume.

### Consistent Hashing
- Modulo hashing: adding 1 server to 10 → move ~90% of data. Consistent hashing → ~10%.
- Used in: Redis Cluster, Cassandra, DynamoDB, distributed caches.
- Enables elastic scaling without massive data migrations.

### CAP Theorem
Network partitions are inevitable → you choose between consistency and availability.
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

## Common Patterns

### 1. Real-Time Updates
**Problem**: Push live data to clients.
**Approach**: HTTP polling → SSE for server-push → WebSockets for bidirectional. Server-side: pub/sub (Redis) or consistent hash ring for stateful connections.
**Insight**: <200ms feels real-time. At extreme volume (live comments), sample the stream — users experience "vibe" not individual items.

### 2. Long-Running Tasks
**Problem**: Operations taking seconds to minutes (encoding, report generation).
**Approach**: Accept → return job ID → queue (Kafka/SQS) → workers process → client polls or gets callback.
**Insight**: Don't queue short tasks (<1s). Synchronous is simpler and gives clearer backpressure.

### 3. Contention
**Problem**: Multiple actors competing for same resource (last ticket, auction bid).
**Approach**: DB transactions → pessimistic locking → optimistic locking → distributed locks → queue-based serialization. Escalate only as needed.
**Insight**: Queue-based serialization (one request at a time per resource) prevents double-booking elegantly.

### 4. Scaling Reads
**Problem**: Read traffic vastly exceeds writes.
**Approach**: Indexing → denormalization → read replicas → Redis cache → CDN (escalation order).
**Insight**: Cache the hot path aggressively. Most systems are read-heavy.

### 5. Scaling Writes
**Problem**: Single DB can't handle write throughput.
**Approach**: Write queues for burst absorption → horizontal sharding → vertical partitioning → load shedding.
**Insight**: Partition key is everything. Bad key = hot partitions = worse than no sharding.

### 6. Large Blobs
**Problem**: Files/media routing through app servers creates bottlenecks.
**Approach**: Presigned URLs for direct client↔S3 upload/download. CDN for distribution. Metadata in DB, files in blob storage.
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
**Key**: Base62 encoding. Aggressive Redis caching — URLs rarely change. Optimize read path obsessively.

### Dropbox (File Sync)
**Challenge**: Sync across devices without re-uploading entire files.
**Key**: Chunk files into blocks, SHA-256 hash each. Only sync changed chunks (deduplication). Metadata in DB, chunks in blob storage.

### News Aggregator (Google News)
**Challenge**: Aggregate thousands of sources into personalized feeds.
**Key**: Crawl/ingest from publishers, deduplicate similar stories. Rank by relevance (recency, engagement, user interests). Cursor-based pagination for infinite scroll. Cache precomputed feeds.

### Ticketmaster (Booking)
**Challenge**: Extreme contention — 10K seats, millions of users.
**Key**: Queue-based serialization instead of long DB locks. Virtual waiting room to control inflow. Strong consistency for booking, eventual for browsing.

### Facebook News Feed
**Challenge**: Fan-out — one post must appear in millions of feeds.
**Key**: Hybrid fanout — on-write for normal users (precompute), on-read for celebrities (too many followers). Merge at read time.

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
**Key**: Geohash/quadtree for proximity. Elasticsearch for full-text + geo compound queries. Rank by proximity × rating × review confidence. CDN for images. Handle hotspot areas (Times Square) with sharding/caching.

### Strava (Fitness Tracking)
**Challenge**: GPS trace storage, segment matching, leaderboards.
**Key**: Store GPS traces as time-series. Match traces against predefined segments (road/trail stretches). Leaderboards per segment — sorted set in Redis or materialized view. Batch-process new activities against all matching segments.

### Rate Limiter
**Challenge**: Distributed rate limiting across multiple gateway instances.
**Key**: Token bucket algorithm (burst-friendly). Redis for central state. Lua scripts for atomic read-calculate-update. One Redis key with TTL per bucket.

### Online Auction (eBay)
**Challenge**: Real-time bidding with contention at auction close.
**Key**: Partition by auction ID to reduce contention. Server-side timestamps for bid ordering (don't trust client clocks). Event stream for real-time bid updates via WebSocket/SSE. Optimistic locking — reject bid if current highest changed.

### Facebook Live Comments
**Challenge**: Thousands of comments/sec per stream, millions of viewers.
**Key**: SSE (server-push sufficient). At extreme volume, sample the stream. Availability over consistency. <200ms target.

### Facebook Post Search
**Challenge**: Full-text search at massive scale.
**Key**: Inverted index — map keywords → document IDs. Cap per-keyword index size (1K-10K). Cold keywords → blob storage. Rank by relevance + recency + social proximity.

### Price Tracking (CamelCamelCamel)
**Challenge**: Monitor millions of product prices, alert on drops.
**Key**: Distributed scraper pools partitioned by product range. Time-series storage for price history. Threshold-based notifications via queue. Retry with exponential backoff for scraper failures. Dead-letter queue for failed alerts.

### Instagram (Photo Sharing)
**Challenge**: Feed generation + image storage at massive scale.
**Key**: Similar fan-out to Facebook News Feed. Presigned URLs for image upload to S3. CDN for serving. Transcode images to multiple sizes. Stories = ephemeral content with TTL.

### YouTube Top K
**Challenge**: Precisely count top K most-viewed videos across time windows.
**Key**: Streaming aggregation — Kafka → Flink with windowed counters. Use heap for maintaining top K per window. Multi-granularity: aggregate hourly, roll up to daily/monthly. Batch correction path for accuracy.

### Uber (Ride Matching)
**Challenge**: Real-time location matching at ~2M updates/sec.
**Key**: Geohash spatial indexing. Location Service ingests GPS via Kafka. Match: rider's geohash → drivers in same + adjacent cells. Redis for ephemeral driver state with aggressive TTL.

### Robinhood (Trading)
**Challenge**: Real-time market data + order execution with strict correctness.
**Key**: Exchange feeds → normalize → Kafka pub/sub. In-memory cache for frequently accessed symbols. WebSockets for live price streaming. Orders are synchronous request/response to exchange. Idempotency keys prevent duplicate orders.

### Google Docs (Collaboration)
**Challenge**: Multiple users editing same document simultaneously.
**Key**: Operational Transform (OT) — each edit is an operation (insert/delete at position), server transforms concurrent operations to maintain consistency. WebSockets for real-time sync. Central server as source of truth. CRDTs are an alternative for decentralized/offline-first scenarios.

### Distributed Cache
**Challenge**: Build a cache layer that scales horizontally.
**Key**: Consistent hashing for key distribution across nodes. LRU eviction policy. Hot key mitigation via read replicas across multiple nodes. Cluster topology changes move minimal data. Client-side consistent hash ring for routing.

### YouTube (Video Streaming)
**Challenge**: Upload → processing → adaptive streaming globally.
**Key**: Resumable multipart uploads. Post-processing: transcode to multiple resolutions, generate HLS/DASH manifest. CDN edge caching. Separate hot/cold storage tiers.

### Job Scheduler
**Challenge**: Reliable distributed task scheduling (cron + ad-hoc).
**Key**: Jobs stored in DB with schedule metadata. Scheduler service checks for due jobs, enqueues to Kafka/SQS. Workers pull and execute. Decentralized pull model scales better than centralized assignment. Retry with backoff for failures. Execution history for debugging.

### Web Crawler
**Challenge**: Crawl billions of pages without loops or traps.
**Key**: Frontier queue holds URLs to crawl. Check metadata DB to avoid re-crawling. DNS caching. Max depth limit (15-20 hops) for crawler traps. Rate-limit per domain, respect robots.txt.

### Ad Click Aggregator
**Challenge**: High-throughput event ingestion with real-time + batch analytics.
**Key**: Dual path — Kafka → Flink for real-time, S3 → Spark for batch correction. OLAP (ClickHouse/Druid) for serving. Idempotency keys prevent double-counting. Salting to mitigate hot-key skew.

### Payment System
**Challenge**: Correctness — no double charges, no lost payments.
**Key**: Idempotency keys on every request (client-generated UUID). Server checks if key already processed → returns cached result. Exactly-once = at-least-once (retry) + at-most-once (idempotency check). Saga pattern for multi-step flows (charge → fulfill → settle) with compensating transactions on failure.

### Metrics Monitoring (Datadog)
**Challenge**: Ingest millions of metrics/sec, query across time ranges, alert on thresholds.
**Key**: Time-series DB (InfluxDB, TimescaleDB, or custom). Downsampling: raw → 1min → 5min → 1hr rollups for older data (288x reduction). Aggregation at collection agent, ingestion pipeline, or query time. Alert rules evaluate over sliding windows (e.g., "p99 > 500ms for 5min").

### Local Delivery (DoorDash)
**Challenge**: Three-sided marketplace with real-time coordination.
**Key**: Geospatial indexing for driver/merchant discovery. Order = state machine (placed → accepted → picked up → delivered). Location Service ingests GPS via Kafka. Traffic spikes at meal times — queue-based absorption.
