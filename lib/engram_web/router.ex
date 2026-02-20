defmodule EngramWeb.Router do
  use EngramWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug EngramWeb.Plugs.Authenticate
  end

  # Health check (unauthenticated)
  scope "/api/v1", EngramWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Authenticated API
  scope "/api/v1", EngramWeb do
    pipe_through [:api, :authenticated]

    # Memory CRUD
    resources "/memories", MemoryController, only: [:index, :show, :create, :delete]

    # Semantic search & context
    post "/memories/search", MemoryController, :search
    post "/memories/context", MemoryController, :context

    # Consolidation
    post "/memories/consolidate", MemoryController, :consolidate

    # Stats
    get "/memories/stats", MemoryController, :stats
  end
end
