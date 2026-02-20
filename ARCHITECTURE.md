# Engram — Architecture Document

> **Version:** 1.0.0
> **Date:** 2026-02-20
> **Status:** Approved — Building
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

## Three-Layer Stack

```
┌─────────────────────────────────────┐
│  FLUX FIELD (hot, volatile, fast)   │  ← query interface
│  Computed projection. Rebuildable.  │
│  collapse, interfere, sample, etc.  │
├─────────────────────────────────────┤
│  EVENT LOG (cold, immutable, truth) │  ← source of truth
│  Append-only. Every write is event. │
│  Checkpointed. Replayable.         │
├─────────────────────────────────────┤
│  INTELLIGENCE (async, pluggable)    │  ← the engine
│  Flux-native: cluster, decay, rank │
│  LLM-delegated: summarize, resolve │
│  Self-reflection at each clearance  │
└─────────────────────────────────────┘
```

- **Flux Field** is a computed projection of the event log. Rebuildable from events at any time.
- **Event Log** is the source of truth. Immutable. Append-only.
- **Intelligence** runs async. Flux-native for structural ops, LLM-delegated for language ops. Boundary shrinks as Flux matures.

---

## Constraints (60)

### Architecture (1-7)
1. Shardable — memories distribute across nodes
2. Clusterable — multiple instances, no SPOF
3. Embeddable — sidecar or standalone deployment
4. Protocol-compatible — drop-in behind existing `memory:*` events
5. Embedding-agnostic — pluggable vector providers
6. Storage-agnostic — pluggable backends
7. Stateless compute — any node can serve any request

### Data Model (8-13)
8. Append-only core — events are immutable
9. Multi-scope isolation — tenant → fleet → squad → agent
10. Content-addressable — dedup by hash
11. Graph-linked — memories reference each other
12. Schema-free values — any JSON payload
13. Versioned — version chain, diffs queryable

### Intelligence (14-19)
14. Semantic search — vector similarity
15. Auto-consolidation — related memories merge over time
16. Decay scoring — memories lose relevance without reinforcement
17. Contradiction detection — flag conflicting memories
18. Context assembly — token-budget-aware retrieval
19. Cross-scope inference — fleet patterns from squad/agent data

### Operations (20-25)
20. GDPR-compliant redaction — crypto-shred content, keep envelope
21. Quota-aware — per-tenant limits
22. Observable — Prometheus metrics, structured logs
23. Hot path < 10ms — get/set stays fast
24. Backpressure — intelligence workers don't starve reads
25. Zero-config bootstrap — works with defaults

### Query (26-32)
26. Flux-native query language — agents write Flux expressions to search
27. Query planner — Flux queries compile to execution plans
28. Hybrid retrieval — combine structured + vector + graph in one query
29. Token-aware responses — truncate/summarize to fit budget
30. Query caching — identical queries within TTL return cached
31. Streaming results — large results stream, not buffered
32. Query cost estimation — return estimated cost before executing

### Security (33-44)
33. Default-deny scope isolation with ACL-based promotion
34. Classification labels — optional regulatory metadata
35. Audit trail — every read/write/search logged, immutable
36. Retention policies — automated, per scope/classification
37. Legal hold — freeze memories from deletion/consolidation
38. Role-based permissions — granular per scope
39. Time-boxed access — temporary elevated access, auto-revoke
40. Break-glass — emergency cross-scope with justification
41. Region pinning — data sovereignty, shard by geography
42. Encryption at rest per scope — tenant/squad-level keys
43. Poisoning detection — anomalous write pattern detection
44. Provenance chain — full trust/source tracking

### Data Lifecycle (45-50)
45. Nothing removed from graph — redaction (reversible) and deletion (crypto-shred, irreversible) are separate statuses. Envelope + audit persist forever.
46. Tiered storage — hot/cold, same query interface
47. Redaction = status + access level elevation, policy-configurable
48. Legal override capability — courts can force un-redact/un-delete
49. Legal escrow — deleted content keys held in escrow vault, true destruction after escrow period + no holds
50. Legal notice registry — log of court orders, auto-freeze related memories

### Intelligence Engine (51-56)
51. Self-reflection is native field operation — runs at each clearance level independently
52. Reflection-created relations tagged `author: system/reflection`
53. Consolidation never destroys minority opinions — contradictions produce dissent records
54. Consolidated memory clearance = max(source clearances)
55. Consolidation is idempotent
56. Intelligence engine pluggable — Flux-native for structural, LLM-delegated for language

### Safety (57-60)
57. Flux field is computed projection of immutable event log — rebuildable
58. Field snapshots/checkpoints — rollback = restore + replay
59. Deformation validation — delta threshold, elevated clearance for large changes
60. Shadow fields — experimental deformations on copy before promotion

---

## Query Grammar (Flux-Native)

Every Engram operation maps to a Flux primitive:

| Engram Operation | Flux Primitive | Description |
|---|---|---|
| Semantic search | `collapse` | Query field with intent vector |
| Context assembly | `sample` | Extract neighborhood within token budget |
| Write/consolidate | `deform` | Field learns from experience |
| Correlation discovery | `interfere` | Two field projections interact |
| Access control | `project` | Filter by clearance subspace |
| Read | `observe` | Field state readout |
| Subscribe | `.stream()` | Real-time PubSub |

### Examples

```flux
field Ψ : Memory { dims: 1536 }

// Semantic search
results ← collapse Ψ { intent: "MoMo timeout handling", mode: probability > 0.7, yield: top(10) }

// Filtered search
results ← collapse Ψ { intent: "transaction failures", yield: top(5) }
    |> filter { where: scope == squad("verification"), where: tags contains "kyc" }

// Context assembly
context ← sample Ψ { around: "deploy Korido v2.1", radius: 3.0, budget: 4000 tokens }

// Clearance-scoped
accessible ← project Ψ onto clearance(L3) |> collapse { intent: "M&A analysis", yield: top(10) }

// Self-reflection (runs at each clearance level)
for level in clearance_levels {
    projected ← project Ψ onto clearance(level)
    patterns ← interfere { projected, projected, mode: constructive > 0.6 }
    deform projected { experience: patterns, alpha: 0.2 }
}
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
    content: bytes,
    content_type: string,
    embedding: tensor<1536>?,
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
    memory_id: uuid,
    action: enum { created, updated, accessed, redacted, un_redacted, deleted, held, released, promoted, consolidated, linked, decayed },
    actor: uuid,
    actor_type: enum { agent, system, admin, legal },
    metadata: json,
    timestamp: timestamp,
    legal_ref: string?,
}
```

---

## Consolidation Algorithm

### Triggers
1. **Density** — N+ memories in same vector neighborhood (similarity > 0.85)
2. **Temporal** — Same key updated M+ times in window
3. **Relation** — Cluster of `supports` relations forms natural group
4. **Manual** — Agent/admin calls `deform` explicitly

### Process
1. **DETECT** — Self-reflection scans at each clearance level
2. **RANK** — Score clusters by value (author diversity, contradiction count, age)
3. **SYNTHESIZE** — Create consolidated memory (Flux-native for structure, LLM for content)
4. **DEMOTE** — Source memories → `superseded` status, decay reduced

### Rules
- Clearance of consolidation = max(source clearances)
- Contradictions produce dissent records (never silently discarded)
- Idempotent — running twice produces same output
- Consolidation at clearance L3 can only merge L3-or-below

---

## Cluster Protocol

- **Shard key:** `(tenant_id, fleet_id)` — fleet co-located
- **Replication:** N replicas (default 2), async
- **Discovery:** Gossip protocol + DNS fallback
- **Region pinning:** Shard placement tags, routing respects geography
- **Consolidation:** Runs on primary per shard, idempotent on failover

---

## Build Phases

### Phase 0: Flux Systems Primitives (NOW)
Extend Flux language with I/O:
- `listen` — TCP/HTTP server
- `connect` — storage driver (SQLite embedded)
- `route` — HTTP routing
- `encode`/`decode` — JSON serialization
- Async/concurrent execution model

### Phase 1: Engram MVP
- FluxField as memory store
- collapse = semantic search
- deform = write/consolidate
- observe = read
- project = clearance filtering
- REST API wrapping Flux operations
- Drop-in replace ringforge_memory

### Phase 2: Intelligence Layer
- Self-reflection at clearance levels
- Consolidation with LLM synthesis
- Decay engine
- Contradiction detection

### Phase 3: Cluster Mode
- Gossip protocol, sharding, replication
- Region pinning
- Tiered storage (hot/cold)

### Phase 4: Enterprise
- Legal escrow, hold registry
- Classification labels
- Break-glass access
- Audit export

### Phase 5: Pure Flux
- Migrate LLM functions to Flux-native
- Field dynamics for synthesis
- Self-hosting compiler (Stage 2)
- This is the moat

---

## Citizens of Engram

1. **Memory** — the core unit of knowledge
2. **Agent** — author/consumer (recognized by agent_id from fleet)
3. **Scope** — visibility boundary (tenant → fleet → squad → agent)
4. **Relation** — connection between memories (supports, contradicts, supersedes, etc.)
5. **Consolidation** — merged higher-order summary of related memories

---

## Authority Hierarchy

1. **Law** (court order) — can force anything
2. **Tenant admin** — controls policy within legal bounds
3. **Scope rules** — normal access control
4. **Agent** — operates within all of the above

---

*Approved by Ben Ouattara, 2026-02-20*
