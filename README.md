# Engram

> Collective memory for AI fleets.

Engram is the persistent memory and knowledge layer for AI agent meshes. It provides semantic search, scoped memory isolation, event sourcing, and automatic memory consolidation.

**RingForge** = nervous system · **Engram** = brain

## Quick Start

```bash
# Dependencies
mix deps.get

# Database (requires PostgreSQL with pgvector extension)
mix ecto.setup

# Run
mix phx.server
```

The API is available at `http://localhost:4000/api/v1`.

## Prerequisites

- Elixir 1.15+
- PostgreSQL 15+ with [pgvector](https://github.com/pgvector/pgvector) extension
- Redis (optional, for caching — not yet implemented)

## API

All endpoints (except health) require a Bearer token:

```
Authorization: Bearer eng_your_api_key_here
```

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/health` | Health check |
| `POST` | `/api/v1/memories` | Store a memory |
| `GET` | `/api/v1/memories` | List memories (filterable) |
| `GET` | `/api/v1/memories/:id` | Get a memory by ID |
| `DELETE` | `/api/v1/memories/:id` | Forget a memory (GDPR) |
| `POST` | `/api/v1/memories/search` | Semantic vector search |
| `POST` | `/api/v1/memories/context` | Build context window |
| `POST` | `/api/v1/memories/consolidate` | Find consolidation candidates |
| `GET` | `/api/v1/memories/stats` | Memory statistics |

### Store a Memory

```bash
curl -X POST http://localhost:4000/api/v1/memories \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Deployments require a database migration check first",
    "kind": "knowledge",
    "tags": ["deployment", "database"],
    "confidence": 0.95
  }'
```

### Semantic Search

```bash
curl -X POST http://localhost:4000/api/v1/memories/search \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "embedding": [0.1, 0.2, ...],
    "limit": 5,
    "threshold": 0.7
  }'
```

## Architecture

```
Engram.Memories      — Core CRUD, tagging, TTL, access tracking
Engram.Search        — pgvector semantic search, context windows
Engram.Consolidation — Background memory merging/summarization
Engram.Scoping       — Tenant → Fleet → Squad → Agent isolation
Engram.Events        — Immutable event sourcing, audit trail
Engram.Auth          — API key authentication
```

## Memory Scoping

Every memory belongs to a hierarchy:

```
Tenant (required)
  └── Fleet
       └── Squad
            └── Agent
```

API keys are scoped — a key with `fleet_id` can only access memories in that fleet.

## Memory Kinds

`knowledge` · `observation` · `decision` · `discovery` · `error` · `context` · `consolidated`

## Development

```bash
mix test              # Run tests
mix format            # Format code
mix ecto.reset        # Reset database
```

## License

Private — Ainotek / eshe-huli
