defmodule Engram.Memories do
  @moduledoc """
  The Memories context — core CRUD for the fleet memory store.

  Memories are the fundamental unit of knowledge in Engram. Each memory
  has content, metadata, tags, optional vector embeddings, and belongs
  to a specific scope (tenant/fleet/squad/agent).
  """

  import Ecto.Query
  alias Engram.Repo
  alias Engram.Memories.Memory
  alias Engram.Events

  @doc """
  Creates a new memory.

  ## Parameters
    - attrs: Map with :content, :kind, :tags, :metadata, :scope_*

  ## Examples
      iex> create_memory(%{content: "Deploy requires restart", kind: "knowledge"})
      {:ok, %Memory{}}
  """
  def create_memory(attrs \\ %{}) do
    %Memory{}
    |> Memory.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(fn memory ->
      Events.emit(:memory_created, memory)
    end)
  end

  @doc "Retrieves a memory by ID, scoped to tenant."
  def get_memory(id, scope \\ %{}) do
    Memory
    |> scope_query(scope)
    |> Repo.get(id)
    |> case do
      nil -> {:error, :not_found}
      memory -> {:ok, touch_accessed(memory)}
    end
  end

  @doc "Lists memories with optional filters."
  def list_memories(filters \\ %{}) do
    Memory
    |> scope_query(filters)
    |> filter_by_tags(filters[:tags])
    |> filter_by_kind(filters[:kind])
    |> filter_by_author(filters[:author_id])
    |> filter_by_time_range(filters[:after], filters[:before])
    |> order_by([m], desc: m.inserted_at)
    |> limit_query(filters[:limit] || 50)
    |> offset_query(filters[:offset] || 0)
    |> Repo.all()
  end

  @doc "Updates an existing memory."
  def update_memory(%Memory{} = memory, attrs) do
    memory
    |> Memory.changeset(attrs)
    |> Repo.update()
    |> tap_ok(fn updated ->
      Events.emit(:memory_updated, updated)
    end)
  end

  @doc """
  Deletes a memory (GDPR-compliant forget).

  This is a hard delete — the memory content is removed. An event
  is recorded for audit purposes, but the content itself is gone.
  """
  def delete_memory(%Memory{} = memory) do
    Events.emit(:memory_deleted, %{id: memory.id, scope: memory_scope(memory)})
    Repo.delete(memory)
  end

  @doc "Returns memory stats for a given scope."
  def stats(scope \\ %{}) do
    query = scope_query(Memory, scope)

    %{
      total: Repo.aggregate(query, :count),
      by_kind:
        query
        |> group_by([m], m.kind)
        |> select([m], {m.kind, count(m.id)})
        |> Repo.all()
        |> Map.new(),
      oldest: Repo.one(from m in query, order_by: [asc: m.inserted_at], limit: 1, select: m.inserted_at),
      newest: Repo.one(from m in query, order_by: [desc: m.inserted_at], limit: 1, select: m.inserted_at)
    }
  end

  # --- Private helpers ---

  defp scope_query(queryable, %{tenant_id: tid, fleet_id: fid, squad_id: sid, agent_id: aid})
       when not is_nil(tid) do
    queryable
    |> where([m], m.tenant_id == ^tid)
    |> then(fn q -> if fid, do: where(q, [m], m.fleet_id == ^fid), else: q end)
    |> then(fn q -> if sid, do: where(q, [m], m.squad_id == ^sid), else: q end)
    |> then(fn q -> if aid, do: where(q, [m], m.agent_id == ^aid), else: q end)
  end

  defp scope_query(queryable, %{tenant_id: tid}) when not is_nil(tid) do
    where(queryable, [m], m.tenant_id == ^tid)
  end

  defp scope_query(queryable, _), do: queryable

  defp filter_by_tags(query, nil), do: query
  defp filter_by_tags(query, []), do: query
  defp filter_by_tags(query, tags) when is_list(tags) do
    where(query, [m], fragment("? @> ?", m.tags, ^tags))
  end

  defp filter_by_kind(query, nil), do: query
  defp filter_by_kind(query, kind), do: where(query, [m], m.kind == ^kind)

  defp filter_by_author(query, nil), do: query
  defp filter_by_author(query, author_id), do: where(query, [m], m.author_id == ^author_id)

  defp filter_by_time_range(query, nil, nil), do: query
  defp filter_by_time_range(query, after_dt, nil), do: where(query, [m], m.inserted_at >= ^after_dt)
  defp filter_by_time_range(query, nil, before_dt), do: where(query, [m], m.inserted_at <= ^before_dt)
  defp filter_by_time_range(query, after_dt, before_dt) do
    where(query, [m], m.inserted_at >= ^after_dt and m.inserted_at <= ^before_dt)
  end

  defp limit_query(query, limit), do: limit(query, ^limit)
  defp offset_query(query, 0), do: query
  defp offset_query(query, offset), do: offset(query, ^offset)

  defp touch_accessed(memory) do
    now = DateTime.utc_now()
    count = (memory.access_count || 0) + 1

    memory
    |> Memory.access_changeset(%{last_accessed_at: now, access_count: count})
    |> Repo.update!()
  end

  defp memory_scope(memory) do
    %{
      tenant_id: memory.tenant_id,
      fleet_id: memory.fleet_id,
      squad_id: memory.squad_id,
      agent_id: memory.agent_id
    }
  end

  defp tap_ok({:ok, value} = result, fun) do
    fun.(value)
    result
  end

  defp tap_ok(error, _fun), do: error
end
