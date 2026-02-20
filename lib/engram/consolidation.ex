defmodule Engram.Consolidation do
  @moduledoc """
  Memory consolidation — merging related memories into distilled knowledge.

  Like human memory: raw experiences are temporary, consolidated
  knowledge persists. This module provides the framework for
  periodic consolidation workers.
  """

  alias Engram.Memories
  alias Engram.Memories.Memory
  alias Engram.Repo

  import Ecto.Query

  @doc """
  Finds candidate memories for consolidation within a scope.

  Returns groups of related memories that could be merged.
  Currently groups by tags — semantic grouping comes later.
  """
  def find_candidates(scope, opts \\ []) do
    min_group_size = Keyword.get(opts, :min_group_size, 3)
    max_age_days = Keyword.get(opts, :max_age_days, 7)
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_days * 86_400, :second)

    # Find unconsolidated memories older than cutoff
    from(m in Memory,
      where: m.consolidated == false,
      where: m.inserted_at <= ^cutoff,
      where: m.tenant_id == ^scope.tenant_id,
      select: m
    )
    |> apply_fleet_filter(scope)
    |> Repo.all()
    |> group_by_tags(min_group_size)
  end

  @doc """
  Consolidates a group of memories into a single consolidated memory.

  The consolidated memory receives a summary and references to its sources.
  Source memories are marked as consolidated.
  """
  def consolidate(memories, summary, scope) when is_list(memories) and length(memories) >= 2 do
    source_ids = Enum.map(memories, & &1.id)
    combined_tags = memories |> Enum.flat_map(& &1.tags) |> Enum.uniq()

    Repo.transaction(fn ->
      # Create consolidated memory
      {:ok, consolidated} =
        Memories.create_memory(%{
          content: summary,
          kind: "consolidated",
          tags: combined_tags,
          tenant_id: scope.tenant_id,
          fleet_id: scope[:fleet_id],
          squad_id: scope[:squad_id],
          metadata: %{"source_ids" => source_ids, "source_count" => length(memories)},
          confidence: avg_confidence(memories)
        })

      # Mark source memories as consolidated
      from(m in Memory, where: m.id in ^source_ids)
      |> Repo.update_all(
        set: [consolidated: true, consolidated_into_id: consolidated.id]
      )

      consolidated
    end)
  end

  # --- Private ---

  defp apply_fleet_filter(query, %{fleet_id: fid}) when not is_nil(fid) do
    where(query, [m], m.fleet_id == ^fid)
  end

  defp apply_fleet_filter(query, _), do: query

  defp group_by_tags(memories, min_size) do
    memories
    |> Enum.reduce(%{}, fn memory, groups ->
      Enum.reduce(memory.tags, groups, fn tag, acc ->
        Map.update(acc, tag, [memory], &[memory | &1])
      end)
    end)
    |> Enum.filter(fn {_tag, members} -> length(members) >= min_size end)
    |> Enum.map(fn {tag, members} -> %{tag: tag, memories: members} end)
  end

  defp avg_confidence(memories) do
    memories
    |> Enum.map(& &1.confidence)
    |> Enum.reject(&is_nil/1)
    |> then(fn
      [] -> 1.0
      scores -> Enum.sum(scores) / length(scores)
    end)
    |> Float.round(3)
  end
end
