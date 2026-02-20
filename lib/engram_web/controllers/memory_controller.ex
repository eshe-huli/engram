defmodule EngramWeb.MemoryController do
  use EngramWeb, :controller

  alias Engram.Memories
  alias Engram.Search

  action_fallback EngramWeb.FallbackController

  @doc "POST /api/v1/memories"
  def create(conn, params) do
    attrs = Map.merge(params, conn.assigns.scope)

    case Memories.create_memory(attrs) do
      {:ok, memory} ->
        conn
        |> put_status(:created)
        |> json(render_memory(memory))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation failed", details: format_errors(changeset)})
    end
  end

  @doc "GET /api/v1/memories/:id"
  def show(conn, %{"id" => id}) do
    case Memories.get_memory(id, conn.assigns.scope) do
      {:ok, memory} -> json(conn, render_memory(memory))
      {:error, :not_found} -> not_found(conn)
    end
  end

  @doc "GET /api/v1/memories"
  def index(conn, params) do
    filters = Map.merge(conn.assigns.scope, normalize_filters(params))
    memories = Memories.list_memories(filters)
    json(conn, %{data: Enum.map(memories, &render_memory/1), count: length(memories)})
  end

  @doc "DELETE /api/v1/memories/:id"
  def delete(conn, %{"id" => id}) do
    with {:ok, memory} <- Memories.get_memory(id, conn.assigns.scope),
         {:ok, _} <- Memories.delete_memory(memory) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} -> not_found(conn)
    end
  end

  @doc "POST /api/v1/memories/search"
  def search(conn, %{"embedding" => embedding} = params) do
    opts = [
      limit: params["limit"] || 10,
      threshold: params["threshold"] || 0.0,
      scope: conn.assigns.scope,
      tags: params["tags"],
      kind: params["kind"]
    ]

    results =
      embedding
      |> Enum.map(&(&1 / 1.0))
      |> Search.semantic_search(opts)
      |> Enum.map(fn {memory, score} ->
        Map.put(render_memory(memory), :similarity, Float.round(score, 4))
      end)

    json(conn, %{data: results, count: length(results)})
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required field: embedding"})
  end

  @doc "POST /api/v1/memories/context"
  def context(conn, %{"embedding" => embedding} = params) do
    opts = [
      max_chars: params["max_chars"] || 10_000,
      scope: conn.assigns.scope,
      limit: params["limit"] || 50
    ]

    results = Search.build_context(embedding, opts)

    context_items =
      Enum.map(results, fn %{memory: m, relevance: r} ->
        %{content: m.content, kind: m.kind, tags: m.tags, relevance: Float.round(r, 4)}
      end)

    json(conn, %{
      data: context_items,
      count: length(context_items),
      total_chars: context_items |> Enum.map(&String.length(&1.content)) |> Enum.sum()
    })
  end

  @doc "POST /api/v1/memories/consolidate"
  def consolidate(conn, _params) do
    scope = conn.assigns.scope
    candidates = Engram.Consolidation.find_candidates(scope)

    json(conn, %{
      candidates: length(candidates),
      groups: Enum.map(candidates, fn g ->
        %{tag: g.tag, count: length(g.memories)}
      end)
    })
  end

  @doc "GET /api/v1/memories/stats"
  def stats(conn, _params) do
    stats = Memories.stats(conn.assigns.scope)
    json(conn, stats)
  end

  # --- Private ---

  defp render_memory(memory) do
    %{
      id: memory.id,
      content: memory.content,
      summary: memory.summary,
      kind: memory.kind,
      tags: memory.tags,
      metadata: memory.metadata,
      source: memory.source,
      confidence: memory.confidence,
      author_id: memory.author_id,
      tenant_id: memory.tenant_id,
      fleet_id: memory.fleet_id,
      squad_id: memory.squad_id,
      agent_id: memory.agent_id,
      access_count: memory.access_count,
      consolidated: memory.consolidated,
      expires_at: memory.expires_at,
      inserted_at: memory.inserted_at,
      updated_at: memory.updated_at
    }
  end

  defp normalize_filters(params) do
    %{}
    |> maybe_put(:tags, params["tags"])
    |> maybe_put(:kind, params["kind"])
    |> maybe_put(:author_id, params["author_id"])
    |> maybe_put(:limit, parse_int(params["limit"]))
    |> maybe_put(:offset, parse_int(params["offset"]))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{error: "Memory not found"})
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
