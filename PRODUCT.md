# Engram — Fleet Brain for AI Agent Meshes

## The Problem

AI agents forget everything between sessions. In multi-agent fleets, knowledge dies with the agent that learned it. There's no shared memory, no collective intelligence, no way for agents to build on each other's discoveries.

Every time an agent spins up, it starts from zero. Lessons learned are lost. Context built painstakingly over hours evaporates. In a fleet of 50 agents, the same mistakes get made 50 times.

## The Solution

Engram is a persistent, searchable, self-organizing memory layer for AI agent fleets. Store memories, search semantically, build context windows, and let the system consolidate raw experiences into distilled knowledge — automatically.

### How It Works

1. **Agents store memories** — Any agent can write structured memories with metadata, tags, and embeddings
2. **Agents search memories** — Semantic search finds relevant memories even when queries don't match exact keywords
3. **Context windows** — Request pre-built context packages: "give me everything relevant to deploying service X"
4. **Automatic consolidation** — Raw memories get periodically summarized into distilled knowledge (like how human memory works)
5. **Scoped isolation** — Memories are scoped: Tenant → Fleet → Squad → Agent. Access what you need, nothing more.

## Architecture

```
┌─────────────────────────────────────────────┐
│                  Engram API                  │
│         REST + WebSocket Interface           │
├──────────┬──────────┬───────────┬───────────┤
│ Memories │  Search  │ Consolidate│  Scoping  │
│  (CRUD)  │ (Vector) │ (Workers)  │ (Tenancy) │
├──────────┴──────────┴───────────┴───────────┤
│              Event Sourcing                  │
│         (Full audit trail)                   │
├──────────────────┬──────────────────────────┤
│   PostgreSQL     │        Redis             │
│  + pgvector      │   (Hot memory cache)     │
└──────────────────┴──────────────────────────┘
```

## Relationship to RingForge

**RingForge** = nervous system (real-time coordination, presence, messaging)
**Engram** = brain (persistent knowledge, collective memory, intelligence)

Engram is designed to work standalone or as the memory backend for RingForge fleets.

## Tagline

> "Collective memory for AI fleets."

## API Surface

```
POST   /api/v1/memories          — Store a memory
GET    /api/v1/memories/:id      — Retrieve by ID
GET    /api/v1/memories          — List/filter (by tags, author, time range)
POST   /api/v1/memories/search   — Semantic search (vector similarity)
POST   /api/v1/memories/context  — Build context window for a task/query
DELETE /api/v1/memories/:id      — Forget (GDPR-compliant)
POST   /api/v1/memories/consolidate — Trigger consolidation for a scope
GET    /api/v1/memories/stats    — Usage stats per tenant/fleet/agent

WS     /ws/memories              — Real-time memory feed
```

## Core Principles

- **Immutable events, mutable state** — Every write is an event. State is derived.
- **Scoping is not optional** — Every memory belongs to a tenant/fleet/squad/agent hierarchy
- **Forgetting is a feature** — GDPR-compliant deletion, TTL-based expiry, explicit forget
- **Consolidation over accumulation** — Raw memories are temporary; distilled knowledge persists
- **API-first** — No UI. Pure API. Let clients build their own interfaces.

## Status

🟡 **Scaffolded** — Project structure in place, core schemas defined, API routes configured. Ready for implementation.
