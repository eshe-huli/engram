# Engram — Architecture Document

> **Version:** 2.1.0
> **Date:** 2026-02-20
> **Status:** Approved — Scope-Native Clustering added
> **Repository:** https://github.com/eshe-huli/engram

---

## What Is Engram?

Engram is the **fleet brain** for RingForge — the persistent, intelligent memory layer for AI agent meshes. It replaces RingForge's current flat key-value memory store with a Flux-native field that supports semantic search, self-reflection, consolidation, and clearance-scoped access control.

**RingForge = nervous system. Engram = brain.**

Engram IS a Flux field: `field Ψ : Memory { dims: 1536 }`

---

## Language

Engram is written in **Flux** — its own language, not a superset of Swift.

### Bootstrap Stages
- **Stage 1 (NOW):** Flux compiler written in Swift → outputs Swift/Metal/ARM64. Engram written in Flux.
- **Stage 2:** Flux compiler rewritten in Flux (self-hosting). Swift becomes build dependency only.
- **Stage 3:** Flux compiler outputs native binary directly. Swift dependency eliminated entirely.

Engram at Stage 1 drives Flux toward Stage 2. Every missing language feature we hit building Engram becomes a Flux primitive.

---

## Design Philosophy: Why Custom

Engram's storage engine is **custom-built**. Not bolted together from existing databases. Here's why:

### The Problem With Existing Databases

Every existing option forces Engram into someone else's data model:

| Option | What It Forces | What We Lose |
|--------|---------------|-------------|
| **ScyllaDB** | Wide-column partitions, eventual consistency | Ordered global scans, transactions across scopes |
| **FoundationDB** | Key-value with ACID, no vector awareness | Native vector ops, memory-aware storage |
| **Qdrant/Milvus** | Vector-first, metadata is second-class | Event sourcing, graph relations, crypto-shredding |
| **Neo4j** | Graph-first, vectors are bolted on | Write throughput, event log, hot-path latency |
| **PostgreSQL + pgvector** | Relational with vector extension | True distribution, memory-native operations |

Every combination requires **impedance matching** — translating Engram's concepts into foreign models, maintaining multiple systems, handling consistency across boundaries. Each seam is a failure point and a performance cliff.

### What Engram Actually Needs (That Nothing Provides)

1. **Unified event log + vector index + graph** — not three databases stitched together
2. **Clearance as a storage primitive** — not a query-time filter bolted on top
3. **Decay as a first-class operation** — the storage engine itself understands memory relevance
4. **Crypto-shredding per memory** — encryption key management baked into the storage format
5. **Scope isolation at the storage level** — tenant/fleet/squad/agent boundaries are physical, not logical
6. **Flux field projection** — the query interface IS the storage abstraction, not a translation layer
7. **Deterministic replay** — rebuild any state from the event log, verified by checksum

No existing database treats these as core primitives. They'd all be application-level concerns bolted on top. That's the wrong abstraction boundary.

### The TigerBeetle Lesson

TigerBeetle proved that a purpose-built storage engine for a specific domain (financial transactions) outperforms general-purpose databases by **orders of magnitude**. They achieved this by:

- Single static binary, zero dependencies
- Deterministic simulation testing
- Storage engine designed for their exact access patterns
- No impedance mismatch — the domain model IS the storage model

Engram follows the same philosophy for AI agent memory.

---

## Storage Engine: Cortex

Engram's custom storage engine is called **Cortex**. Written in Flux (compiled to Swift/Metal at Stage 1).

### Core Design: Append-Only Log-Structured Merge Engine with Integrated Vector Index

```
┌─────────────────────────────────────────────────────────┐
│                    FLUX FIELD (HOT)                      │
│  Computed projection. In-memory. Rebuildable.            │
│  HNSW vector index + skip list for ordered access        │
│  collapse, interfere, sample, project, observe           │
├─────────────────────────────────────────────────────────┤
│                    CORTEX ENGINE                         │
│                                                          │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ MEMTABLE │  │ WRITE-AHEAD  │  │ SCOPE PARTITIONS │  │
│  │ (active) │  │ LOG (WAL)    │  │ Physical isolation│  │
│  │ sorted   │  │ append-only  │  │ per tenant/fleet  │  │
│  │ in-memory│  │ fsync'd      │  │                   │  │
│  └────┬─────┘  └──────┬───────┘  └────────┬──────────┘  │
│       │               │                    │             │
│  ┌────▼───────────────▼────────────────────▼──────────┐ │
│  │              SST FILES (sorted string tables)       │ │
│  │  ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌────────┐  │ │
│  │  │ Level 0 │ │ Level 1 │ │ Level 2  │ │Level N │  │ │
│  │  │ (hot)   │ │ (warm)  │ │ (cold)   │ │(frozen)│  │ │
│  │  └─────────┘ └─────────┘ └──────────┘ └────────┘  │ │
│  │                                                     │ │
│  │  Each SST contains:                                 │ │
│  │  • Memory entries (key-sorted)                      │ │
│  │  • Embedded vector segments (HNSW graph shards)     │ │
│  │  • Relation adjacency lists (graph edges)           │ │
│  │  • Bloom filters (membership testing)               │ │
│  │  • Encryption envelope (per-scope keys)             │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              EVENT LOG (immutable truth)             │ │
│  │  Append-only. Checksummed. Segmented.               │ │
│  │  Every mutation is an event. Replayable.            │ │
│  │  Separate from SST — never compacted.               │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              ESCROW VAULT                           │ │
│  │  Encryption keys for deleted memories.              │ │
│  │  Separate storage, separate access control.         │ │
│  │  Legal hold integration.                            │ │
│  └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│                    INTELLIGENCE (ASYNC)                   │
│  Flux-native: cluster, decay, rank, consolidate         │
│  LLM-delegated: summarize, synthesize, resolve          │
│  Self-reflection at each clearance level                │
└─────────────────────────────────────────────────────────┘
```

### Why LSM-Tree Architecture

Engram's access pattern is **write-heavy, read-selective**:

- Agents constantly store memories (high write throughput)
- Reads are selective — vector similarity, key lookup, scope-filtered
- Compaction = natural point for decay scoring, consolidation triggers, garbage collection
- Tiered storage maps directly to LSM levels (hot → cold → frozen)

LSM beats B-tree for this workload. And building our own means:

- **Vector segments embedded in SST files** — no separate vector index to synchronize
- **Compaction is intelligence-aware** — decay scores influence merge priority
- **Encryption is per-SST-segment** — crypto-shredding = drop the key, segment becomes unreadable
- **Scope partitions are physical directories** — no row-level filtering, data doesn't even load

### SST File Format: Memory-Native

Each SST file is a self-contained unit with Engram-specific sections:

```
┌──────────────────────────────────┐
│ HEADER                           │
│  magic: "ENGR"                   │
│  version: uint16                 │
│  scope: (tenant, fleet, squad?)  │
│  level: uint8                    │
│  encryption_key_id: uuid         │
│  checksum: sha256                │
├──────────────────────────────────┤
│ DATA BLOCK                       │
│  Sorted memory entries           │
│  Key: (scope, memory_id)         │
│  Value: content + metadata       │
│  Delta-encoded, LZ4 compressed   │
├──────────────────────────────────┤
│ VECTOR BLOCK                     │
│  HNSW graph shard for this SST   │
│  Quantized embeddings (int8/f16) │
│  Navigation layers               │
│  Entry points per level          │
├──────────────────────────────────┤
│ GRAPH BLOCK                      │
│  Adjacency lists (relations)     │
│  Sorted by source memory_id      │
│  Edge: (target, kind, weight)    │
├──────────────────────────────────┤
│ META BLOCK                       │
│  Bloom filter (key membership)   │
│  Min/max key range               │
│  Min/max timestamp               │
│  Vector centroid (for routing)   │
│  Decay score histogram           │
│  Memory count, size stats        │
├──────────────────────────────────┤
│ INDEX BLOCK                      │
│  Block offsets for random access  │
│  Key → offset mapping            │
│  Sparse index (every Nth key)    │
├──────────────────────────────────┤
│ FOOTER                           │
│  Block checksums                 │
│  Format version                  │
│  Encryption nonce                │
└──────────────────────────────────┘
```

**This is the key insight: embedding vectors, graph edges, and key-value data live in the same physical file.** No impedance mismatch. No cross-database consistency issues. Compaction, encryption, and replication operate on the same unit.

### Write Path

```
Agent writes memory
    │
    ▼
WAL append (fsync, crash-safe)
    │
    ▼
Event Log append (immutable history)
    │
    ▼
Memtable insert (sorted skip list)
    │
    ├── Key-value entry
    ├── Vector added to in-memory HNSW index
    └── Relations added to in-memory adjacency list
    │
    ▼ (memtable full or timer)
Flush to SST Level 0
    │
    ▼ (background, deterministic schedule)
Compaction: merge SSTs across levels
    ├── Merge sorted entries
    ├── Rebuild HNSW graph shard for merged set
    ├── Merge adjacency lists
    ├── Compute decay scores → demote/promote
    ├── Trigger consolidation candidates
    └── Crypto-shred if memory status = deleted + key dropped
```

### Read Path

```
Query arrives (collapse, observe, sample, etc.)
    │
    ▼
Scope check — physical partition routing
    │
    ▼
Clearance check — filter accessible levels
    │
    ├── Key lookup (observe):
    │   Memtable → L0 SSTs → L1 → ... (bloom filters skip non-matches)
    │
    ├── Vector search (collapse):
    │   In-memory HNSW → L0 vector blocks → L1 → ...
    │   Merge results by (decay_score × similarity)
    │   Stop when top-K stable across levels
    │
    ├── Graph traversal (interfere):
    │   In-memory adjacency → SST graph blocks
    │   BFS/DFS with clearance pruning
    │
    └── Context assembly (sample):
        Vector search → expand neighbors → budget-aware truncation
```

### Compaction Strategy: Intelligence-Aware

Standard LSM compaction merges by key order. Cortex adds:

1. **Decay-priority compaction** — memories with low decay scores compact first (they're less likely to be read, push them deeper)
2. **Consolidation triggers** — during compaction, if N+ memories in the same vector neighborhood are detected (centroid distance < threshold), flag for consolidation
3. **Crypto-shred during compaction** — deleted memories with expired escrow simply aren't written to the output SST. The encryption key is already dropped. Data physically disappears during natural compaction cycle.
4. **Deterministic scheduling** — compaction work spread evenly across operations (TigerBeetle's approach), bounding worst-case latency

### Vector Index: Integrated HNSW

Not a separate service. The HNSW graph is **part of the storage engine**:

- **In-memory layer**: Full HNSW graph for hot data (memtable + L0)
- **On-disk shards**: Each SST contains a partial HNSW graph for its entries
- **Search**: Query in-memory first, then merge with on-disk shards level by level
- **Quantization**: int8 for on-disk (4× less space), f32 in-memory (full precision)
- **Compaction rebuilds graph shards**: When SSTs merge, their HNSW shards merge too

Why not a separate Qdrant/Milvus?
- **Consistency**: Vector index is always in sync with data (same write path)
- **Locality**: Vector + metadata co-located = no cross-service join
- **Encryption**: Vectors encrypted with same scope key as data
- **Simplicity**: One system, one binary, one replication protocol

### Graph Storage: Integrated Adjacency

Relations (supports, contradicts, supersedes, derives_from, related_to, refines) are stored as sorted adjacency lists:

- **In-memory**: Hash map of `memory_id → [(target, kind, weight)]`
- **On-disk**: Sorted by source memory_id in each SST's graph block
- **Traversal**: Merge in-memory + on-disk, clearance-pruned
- **Compaction**: Adjacency lists merge naturally with SST merge

Why not a separate Neo4j?
- **Engram's graph is simple**: Adjacency lists, not property graph with Cypher queries
- **Max depth ~5**: Relation traversal is shallow (memory → related → related)
- **Co-located data**: Following a relation immediately gives you the memory content
- **No query language mismatch**: Flux's `interfere` compiles directly to adjacency traversal

### Scope Isolation: Physical Partitioning

```
data/
├── tenant_aaa/
│   ├── fleet_001/
│   │   ├── wal/
│   │   ├── events/
│   │   ├── sst/
│   │   │   ├── L0/
│   │   │   ├── L1/
│   │   │   └── L2/
│   │   ├── squad_alpha/
│   │   │   ├── wal/
│   │   │   ├── sst/
│   │   │   └── ...
│   │   └── squad_beta/
│   └── fleet_002/
├── tenant_bbb/
└── escrow/
    ├── tenant_aaa/
    └── tenant_bbb/
```

- **Scope = directory** — not a column filter, a physical boundary
- **Fleet-level is the default shard unit** — all squad/agent data lives under fleet
- **Cross-scope queries** explicitly merge across directories (expensive by design)
- **Encryption keys per scope directory** — crypto-shred = delete key file, entire directory becomes unreadable
- **Escrow vault is separate** — different access control, different backup policy

### Encryption Architecture

```
┌─────────────────────────┐
│ Master Key (HSM/Vault)  │ ← Never leaves secure boundary
├─────────────────────────┤
│ Tenant Key              │ ← Derived from master + tenant_id
├─────────────────────────┤
│ Fleet Key               │ ← Derived from tenant key + fleet_id
├─────────────────────────┤
│ Scope Key               │ ← Derived from fleet key + scope_id
├─────────────────────────┤
│ SST Segment Key         │ ← Random per SST, encrypted with scope key
└─────────────────────────┘

Crypto-shred a memory:
1. Memory marked deleted in event log
2. Memory's individual encryption key removed from scope keyring
3. On next compaction, memory content not written to output SST
4. Individual key held in escrow vault with legal hold metadata
5. After escrow period + no legal holds → key destroyed
6. Envelope (id, timestamps, audit trail) persists forever, content unrecoverable
```

### Deterministic Simulation Testing (DST)

Following TigerBeetle's approach:

- **All I/O abstracted**: Disk, network, clock are injected interfaces
- **Deterministic replay**: Same seed → same execution, every time
- **Fault injection**: Simulate disk failure, network partition, clock skew
- **Cluster in a single process**: Run N replicas with simulated network for testing
- **Property-based testing**: Invariants checked after every operation (e.g., "vector index always consistent with data block")

This is non-negotiable. A memory system that loses or corrupts data is worthless.

---

## Cluster Protocol: Scope-Native Clustering

**Why not Raft:** Single leader bottleneck. Doesn't scale writes horizontally.
**Why not Scylla's token ring:** Hash-based distribution scatters scope data across nodes. Breaks intelligence locality — consolidation, self-reflection, graph traversal all need the full scope locally.
**Our approach:** Scope IS the shard. The semantic boundary that already exists in the data model IS the distribution unit.

### Architecture

```
┌─────────────────────────────────────────────────────┐
│                  SCOPE MAP (gossip-propagated)       │
│                                                      │
│  fleet_001 → owner: Node_A, replicas: [Node_B]      │
│  fleet_002 → owner: Node_B, replicas: [Node_A]      │
│  fleet_003 → owner: Node_A, replicas: [Node_C]      │
│  fleet_004 → owner: Node_C, replicas: [Node_B]      │
│                                                      │
│  Placement: balanced by memory count + write rate    │
│  Hot scopes: 2-3 replicas. Cold scopes: 1 replica.  │
└─────────────────────────────────────────────────────┘

Node A (M4, 10 cores)              Node B (M3, 8 cores)
┌──────────────────────┐          ┌──────────────────────┐
│ OWNER: fleet_001     │──WAL──▶  │ REPLICA: fleet_001   │
│   Core 0-2: squad_α  │ stream  │   WAL replay (async)  │
│   Core 3-4: squad_β  │         │                       │
│   Intelligence ⚡     │         │ OWNER: fleet_002      │
│                      │ ◀──WAL──│   Core 0-3: squads    │
│ OWNER: fleet_003     │ stream  │   Intelligence ⚡      │
│ REPLICA: fleet_002   │         │ REPLICA: fleet_004    │
└──────────────────────┘          └──────────────────────┘
```

### Scope Ownership Model

- **Scope = shard**: `(tenant_id, fleet_id)` is the distribution unit
- **Owner**: Single node responsible for all writes to a scope. Runs intelligence locally.
- **Replicas**: Receive WAL stream from owner. Serve reads (eventual consistency).
- **Sub-sharding**: Within a scope, squads distribute across CPU cores on the owner (shard-per-core, inspired by ScyllaDB). Each core owns specific squads — zero cross-core locks.

### Write Path (Clustered)

```
Agent writes to fleet_001
    │
    ▼
Any node receives request (coordinator)
    │
    ▼
Scope map lookup: fleet_001 → owner: Node_A
    │
    ├── If this IS Node_A: local write (WAL → event log → memtable)
    └── If this is NOT Node_A: forward to Node_A
    │
    ▼
Node_A writes locally
    │
    ▼
WAL entry streamed to replicas (configurable: async or semi-sync)
    │
    ├── Async: owner confirms immediately, replica catches up
    └── Semi-sync: owner waits for 1 replica ack (for critical scopes)
```

### Read Path (Clustered)

```
Agent reads from fleet_001
    │
    ▼
Consistency level?
    │
    ├── STRONG: route to owner (latest data guaranteed)
    ├── EVENTUAL: route to any replica (faster, may be slightly stale)
    └── LOCAL: route to nearest node that has the scope (lowest latency)
```

### Replication: WAL Streaming

- Owner appends to WAL → streams entries to replicas in order
- Replicas replay WAL entries into their own memtable + SST levels
- **Lag tolerance**: Configurable per-scope (default: 5 seconds or 1000 entries)
- If replica falls behind threshold → alert, consider adding replica or reducing load
- Semi-sync mode available for critical scopes (owner waits for 1 replica ack)

### Failure Handling

```
Node A dies (owns fleet_001, fleet_003)
    │
    ▼
Gossip detects failure (phi-accrual, ~5 seconds)
    │
    ▼
Scope map update:
  fleet_001 → owner: Node_B (was replica, promoted)
  fleet_003 → owner: Node_C (was replica, promoted)
    │
    ▼
Promoted replicas start accepting writes
(may have slight lag — last few WAL entries from dead owner lost if async)
    │
    ▼
Node A recovers → rejoins as replica → re-syncs WAL delta
```

### Split-Brain Prevention

- **Ownership leases**: Each scope owner holds a lease with TTL (renewed via gossip heartbeat)
- **Partition rule**: If a node can't renew lease (isolated from majority), it stops accepting writes after TTL expires
- **Reads continue**: Local stale reads still served (available for reads, consistent for writes)
- **Partition heals**: Ownership reconfirmed, writes resume
- **Consistency > availability** for writes during partitions — correct for a memory system where data integrity matters more than uptime

### Scope Migration (Zero-Downtime Scaling)

```
Migrate fleet_003 from Node_A to Node_C:

Phase 1: STREAMING
  - Node_A continues owning fleet_003 (accepting writes)
  - Node_A streams SST files + WAL to Node_C
  - New writes during streaming are also forwarded to Node_C

Phase 2: CATCHUP
  - Node_C replays WAL, builds memtable + SST levels
  - Node_C signals "caught up" to coordinator

Phase 3: FLIP
  - Scope map atomically updates: fleet_003 → owner: Node_C
  - Node_A stops accepting writes for fleet_003
  - Brief forwarding period: any in-flight writes to Node_A are forwarded to Node_C

Phase 4: CLEANUP
  - Node_A drops fleet_003 data (after confirmation)
  - Node_C runs intelligence catchup (consolidation, reflection)
```

### Discovery & Membership

- **Gossip protocol** (SWIM-based) for membership and scope map propagation
- **Phi-accrual failure detector**: Probabilistic, adapts to network conditions
- **Seed nodes**: Bootstrap list for initial cluster join
- **DNS fallback**: SRV records for discovery in production deployments
- **Scope map**: Every node has a full copy, propagated via gossip (small — just scope→node mappings)

### Shard-Per-Core (Within Each Node)

Inspired by ScyllaDB's killer optimization:
- Each CPU core on a node owns specific scopes (or squads within large scopes)
- Requests route directly to the owning core via lock-free queues
- No cross-core coordination for reads or writes within a scope
- M4 (10 cores) = 10 independent scope engines
- M3 (8 cores) = 8 independent scope engines

### Embeddable Mode

Single-node, in-process. Same engine, no network layer. For:
- Development
- Sidecar deployment (agent with local memory)
- Edge devices

Switch from embedded to cluster = configure seed peers + start replication. No data migration — existing scopes become owned by the single node, replicas added as peers join.

### Self-Critique Log (Living Section)

Architecture decisions are never final. This section tracks known weaknesses and planned improvements.

| # | Weakness | Severity | Mitigation | Status |
|---|----------|----------|------------|--------|
| 1 | Single-writer-per-scope hotspot with 500+ concurrent agent writes | Medium | Squad-level sub-sharding across cores on owner node | Designed |
| 2 | Async WAL replication can lose last few writes on owner crash | Medium | Semi-sync mode for critical scopes; configurable lag tolerance | Designed |
| 3 | Scope migration Phase 3 flip has brief forwarding latency | Low | Acceptable — no data loss, ~100ms elevated latency | Accepted |
| 4 | Split-brain sacrifices write availability | Low | Correct tradeoff for memory system — integrity > uptime | Accepted |
| 5 | Gossip convergence time (~5s) means brief unavailability on failure | Low | Phi-accrual tunable; critical scopes can use faster heartbeat | Designed |

---

## Constraints (60)

### Architecture (1-7)
1. Shardable — memories distribute across nodes by scope
2. Clusterable — Raft consensus, no SPOF
3. Embeddable — sidecar or standalone, same binary
4. Protocol-compatible — drop-in behind existing `memory:*` events
5. Embedding-agnostic — pluggable vector providers (OpenAI, Cohere, local)
6. Single binary — Cortex engine, vector index, graph, all in one process
7. Stateless compute — any node can serve any request for its shards

### Data Model (8-13)
8. Append-only event log — immutable source of truth, separate from SSTs
9. Multi-scope isolation — physical directory partitioning, not row filters
10. Content-addressable — dedup by SHA-256 hash
11. Graph-linked — adjacency lists co-located in SST files
12. Schema-free values — any payload, delta-encoded
13. Versioned — version chain, diffs queryable via event log replay

### Intelligence (14-19)
14. Semantic search — integrated HNSW, not a separate service
15. Auto-consolidation — triggered during compaction when density detected
16. Decay scoring — computed during compaction, influences merge priority
17. Contradiction detection — `interfere` patterns flagged automatically
18. Context assembly — `sample` with token-budget-aware truncation
19. Cross-scope inference — explicit merge across scope directories

### Operations (20-25)
20. Crypto-shredding — per-memory encryption keys, hierarchical key derivation
21. Quota-aware — per-scope storage limits enforced at write path
22. Observable — Prometheus metrics, structured logs, per-operation latency histograms
23. Hot path < 10ms — key lookup and top-K vector search for in-memory + L0
24. Backpressure — compaction and intelligence workers yield to reads
25. Zero-config bootstrap — embedded mode works with defaults, cluster needs only peer list

### Query (26-32)
26. Flux-native query language — Flux expressions compile to Cortex operations
27. Query planner — Flux queries → execution plan (which levels, which shards, estimated cost)
28. Hybrid retrieval — key + vector + graph in single query execution
29. Token-aware responses — truncate/summarize to fit budget
30. Query caching — identical queries within TTL return cached (invalidated by writes to scope)
31. Streaming results — large results stream via chunked response
32. Query cost estimation — return estimated I/O cost before executing

### Security (33-44)
33. Default-deny scope isolation — physical partitioning, ACL-based cross-scope promotion
34. Classification labels — optional regulatory metadata on memory entries
35. Audit trail — event log IS the audit trail, immutable, checksummed
36. Retention policies — per-scope, enforced during compaction
37. Legal hold — freeze memories from deletion/consolidation, event logged
38. Role-based permissions — granular per scope, checked at engine level
39. Time-boxed access — temporary elevated access, auto-revoke via TTL
40. Break-glass — emergency cross-scope with justification, logged, alerting
41. Region pinning — shard placement tags, routing respects geography
42. Encryption at rest — hierarchical key derivation, per-scope encryption
43. Poisoning detection — anomalous write pattern detection (rate, vector distribution)
44. Provenance chain — full trust/source tracking per memory

### Data Lifecycle (45-50)
45. Nothing removed from graph — envelope + audit trail persist forever. Content crypto-shredded.
46. Tiered storage — LSM levels = hot/warm/cold/frozen, same query interface
47. Redaction = status change + clearance elevation. Content still exists, access restricted.
48. Legal override — courts can force un-redact. Escrow keys enable recovery.
49. Legal escrow — deleted content keys held in escrow vault. True destruction after period + no holds.
50. Legal notice registry — court orders logged, auto-freeze related memories.

### Intelligence Engine (51-56)
51. Self-reflection is native field operation — runs at each clearance level independently
52. Reflection-created relations tagged `author: system/reflection`
53. Consolidation never destroys minority opinions — contradictions produce dissent records
54. Consolidated memory clearance = max(source clearances)
55. Consolidation is idempotent
56. Intelligence is hybrid — Flux-native for structural ops, LLM-delegated for language ops. Boundary shrinks as Flux matures.

### Safety (57-60)
57. Flux field is computed projection of immutable event log — rebuildable from events
58. Field snapshots/checkpoints — rollback = restore checkpoint + replay events from that point
59. Deformation validation — delta threshold, elevated clearance for large changes
60. Deterministic simulation testing — all I/O abstracted, fault injection, reproducible

---

## Query Grammar (Flux-Native)

Every Engram operation maps to a Flux primitive:

| Engram Operation | Flux Primitive | Cortex Operation |
|---|---|---|
| Semantic search | `collapse` | HNSW query → merge across LSM levels |
| Context assembly | `sample` | Vector search → expand neighbors → budget truncation |
| Write/consolidate | `deform` | WAL append → memtable insert → event log |
| Correlation | `interfere` | Graph traversal → vector neighborhood overlap |
| Access control | `project` | Scope partition routing + clearance filter |
| Read | `observe` | Key lookup through LSM levels (bloom filter skip) |
| Subscribe | `.stream()` | WAL tail + event filter |

### Examples

```flux
field Ψ : Memory { dims: 1536 }

// Semantic search — compiles to HNSW query across LSM levels
results ← collapse Ψ { intent: "MoMo timeout handling", mode: probability > 0.7, yield: top(10) }

// Filtered search — scope partition + vector search
results ← collapse Ψ { intent: "transaction failures", yield: top(5) }
    |> filter { where: scope == squad("verification"), where: tags contains "kyc" }

// Context assembly — vector neighborhood + token budget
context ← sample Ψ { around: "deploy Korido v2.1", radius: 3.0, budget: 4000 tokens }

// Clearance-scoped — physical partition + clearance bitmap filter
accessible ← project Ψ onto clearance(L3) |> collapse { intent: "M&A analysis", yield: top(10) }

// Self-reflection — runs per clearance level
for level in clearance_levels {
    projected ← project Ψ onto clearance(level)
    patterns ← interfere { projected, projected, mode: constructive > 0.6 }
    deform projected { experience: patterns, alpha: 0.2 }
}

// Write — compiles to WAL append + memtable + event log
deform Ψ { experience: new_memory, scope: squad("alpha"), clearance: L2 }

// Subscribe — tails the WAL with scope + event type filter
Ψ.stream() |> filter { where: scope == fleet("001"), where: action == "created" }
```

---

## Data Model

### Memory Entry

```flux
memory {
    id: uuid,
    key: string?,
    version: uint,
    content_hash: sha256,
    content: bytes,                    // encrypted with scope key
    content_type: string,
    embedding: tensor<1536>?,          // quantized int8 on disk, f32 in memory
    summary: string?,
    tenant_id: uuid,
    fleet_id: uuid,
    squad_id: uuid?,
    agent_id: uuid?,
    clearance: clearance<0..255>,
    classification: enum { unclassified, internal, confidential, secret, top_secret, custom(string) },
    status: enum { active, decayed, superseded, redacted, deleted, held },
    redacted_by: uuid?,
    redacted_access: clearance?,
    held_by: string?,
    author: uuid,
    source: string?,
    confidence: probability<0..1>,
    provenance_chain: [uuid],
    relations: [{ target: uuid, kind: enum { supports, contradicts, supersedes, derives_from, related_to, refines }, weight: correlation<-1..1>, created_by: uuid, created_at: timestamp }],
    tags: [string],
    decay_score: probability<0..1>,
    access_count: uint,
    last_accessed: timestamp?,
    reinforced_by: [uuid],
    decay_rate: float,
    created_at: timestamp,
    updated_at: timestamp,
    ttl: timestamp?,
    encryption_key_ref: string?,
    escrow_key_ref: string?,
}
```

### Event Log Entry (append-only)

```flux
memory_event {
    id: uuid,
    sequence: uint64,                  // monotonic, per-scope
    memory_id: uuid,
    action: enum { created, updated, accessed, redacted, un_redacted, deleted, held, released, promoted, consolidated, linked, decayed },
    actor: uuid,
    actor_type: enum { agent, system, admin, legal },
    metadata: json,
    timestamp: timestamp,
    checksum: sha256,                  // chain checksum: hash(prev_checksum + this_event)
    legal_ref: string?,
}
```

---

## Consolidation Algorithm

### Triggers
1. **Density** — during compaction, N+ memories in same vector neighborhood (centroid distance < threshold)
2. **Temporal** — same key updated M+ times in window (detected via version chain)
3. **Relation** — cluster of `supports` relations forms natural group (graph block analysis)
4. **Manual** — agent/admin calls `deform` explicitly

### Process
1. **DETECT** — self-reflection scans at each clearance level (async, during quiet periods)
2. **RANK** — score clusters by value (author diversity, contradiction count, age, access frequency)
3. **SYNTHESIZE** — create consolidated memory (Flux-native for structure, LLM for content)
4. **DEMOTE** — source memories → `superseded` status, decay rate increased

### Rules
- Clearance of consolidation = max(source clearances)
- Contradictions produce dissent records (never silently discarded)
- Idempotent — running twice produces same output (deterministic)
- Consolidation at clearance L3 can only merge L3-or-below

---

## Performance Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| Key lookup | < 5ms | Bloom filter → memtable → L0 |
| Vector top-10 | < 20ms | In-memory HNSW + L0 shards |
| Vector top-10 (full) | < 50ms | All levels, merge-sort results |
| Write (single memory) | < 2ms | WAL append + memtable insert |
| Write (batch 1000) | < 50ms | Batched WAL append |
| Graph traversal (depth 3) | < 30ms | In-memory adjacency + L0-L1 |
| Context assembly (4K tokens) | < 100ms | Vector search + expand + truncate |
| Compaction (L0→L1) | Background | Deterministic schedule, bounded latency impact |

### Throughput Targets (single node)

| Metric | Target |
|--------|--------|
| Writes/sec | 100K+ (batched) |
| Reads/sec | 50K+ |
| Vector queries/sec | 10K+ |
| Memories stored | 100M+ per node |
| Vector dimensions | 1536 default, configurable |

---

## Build Phases

### Phase 0: Flux Systems Primitives ✅ (DONE)
- `listen` — TCP/HTTP server
- `connect` — storage driver abstraction
- `route` — HTTP routing
- `encode`/`decode` — JSON serialization
- Async/concurrent execution model
- 101 tests passing

### Phase 1: Cortex Engine MVP
Build the custom storage engine:
- **WAL**: Append-only, fsync'd, checksummed segments
- **Memtable**: Sorted skip list with integrated vector entries + adjacency list
- **SST Writer/Reader**: Custom file format (data + vector + graph + meta blocks)
- **Compaction**: Level-based merge with decay-aware priority
- **Event Log**: Separate append-only log, chain-checksummed
- **Scope Partitioning**: Physical directory isolation per tenant/fleet
- **Encryption**: Per-scope key derivation, per-SST segment encryption
- **HNSW Index**: In-memory for hot data, on-disk shards per SST
- **Graph Storage**: Adjacency lists in SST graph blocks
- **REST API**: Wrapping Cortex operations via Flux field interface
- **Tests**: DST framework + property-based tests + unit tests

### Phase 2: Intelligence Layer
- Self-reflection at clearance levels
- Consolidation with LLM synthesis
- Decay engine (runs during compaction + background)
- Contradiction detection (vector neighborhood + relation analysis)
- Context assembly with token budgets

### Phase 3: Cluster Mode
- Raft consensus for WAL replication
- Shard assignment and migration
- Gossip-based discovery (SWIM)
- Region pinning
- Rebalancing

### Phase 4: Enterprise
- Legal escrow vault
- Legal hold registry + court order integration
- Classification enforcement
- Break-glass access + alerting
- Audit export (SOC2/GDPR compliance reporting)

### Phase 5: Pure Flux
- Migrate LLM functions to Flux-native as language matures
- Field dynamics for synthesis (PDE-based)
- Self-hosting compiler (Stage 2)
- Eliminate Swift dependency entirely
- This is the moat

---

## Citizens of Engram

1. **Memory** — the core unit of knowledge
2. **Agent** — author/consumer (recognized by agent_id from fleet)
3. **Scope** — visibility boundary (tenant → fleet → squad → agent), physically partitioned
4. **Relation** — connection between memories (supports, contradicts, supersedes, etc.)
5. **Consolidation** — merged higher-order summary of related memories

---

## Authority Hierarchy

1. **Law** (court order) — can force anything, logged, alerting
2. **Tenant admin** — controls policy within legal bounds
3. **Scope rules** — normal access control, physically enforced
4. **Agent** — operates within all of the above

---

## Why This Is The Right Architecture

1. **Single binary** — no external database dependencies. Deploy one binary.
2. **Domain-native storage** — vector, graph, key-value, event log all in one engine. No impedance mismatch.
3. **Encryption is structural** — not a bolt-on. Crypto-shredding falls out naturally from per-scope key management + compaction.
4. **Flux is the interface** — queries compile to engine operations. No translation layer.
5. **Compaction is intelligence** — decay scoring, consolidation triggers, crypto-shredding all happen during the natural compaction cycle.
6. **Deterministic testing** — TigerBeetle-style DST means we can prove correctness.
7. **Scales from laptop to cluster** — same engine, embedded or distributed.
8. **This is the moat** — anyone can bolt Qdrant + ScyllaDB + Neo4j together. Nobody has a memory engine where vectors, graphs, events, encryption, and intelligence are unified at the storage format level.

---

*Redesigned from first principles by Ben Ouattara, 2026-02-20*
