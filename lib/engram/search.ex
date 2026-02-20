defmodule Engram.Search do
  @moduledoc """
  Semantic search using pgvector.

  Provides vector similarity search over memory embeddings.
  Embeddings are expected to be generated externally (by the calling agent
  or an embedding service) and stored with the memory.
  """

  import Ecto.Query
  alias Engram.Repo
  alias Engram.Memories.Memory

  @default_limit 10
  @default_dimensions 1536

  @doc """
  Performs semantic search using cosine similarity.

  ## Parameters
    - embedding: Query vector (list of floats)
    - opts: Keyword list with :limit, :threshold, :scope, :tags, :kind

  ## Returns
    List of {memory, similarity_score} tuples, ordered by relevance.
  """
  def semantic_search(embedding, opts \\ []) when is_list(embedding) do
    limit = Keyword.get(opts, :limit, @default_limit)
    threshold = Keyword.get(opts, :threshold, 0.0)
    scope = Keyword.get(opts, :scope, %{})

    query =
      from m in Memory,
        where: not is_nil(m.embedding),
        select: %{
          memory: m,
          similarity: fragment(
            "1 - (? <=> ?::vector)",
            m.embedding,
            ^embedding
          )
        },
        order_by: [asc: fragment("? <=> ?::vector", m.embedding, ^embedding)],
        limit: ^limit

    query
    |> apply_scope(scope)
    |> apply_tag_filter(Keyword.get(opts, :tags))
    |> apply_kind_filter(Keyword.get(opts, :kind))
    |> Repo.all()
    |> Enum.filter(fn %{similarity: sim} -> sim >= threshold end)
    |> Enum.map(fn %{memory: m, similarity: s} -> {m, s} end)
  end

  @doc """
  Builds a context window — a curated set of memories relevant to a query.

  Takes a query embedding and assembles the most relevant memories,
  respecting a token/character budget.
  """
  def build_context(embedding, opts \\ []) do
    max_chars = Keyword.get(opts, :max_chars, 10_000)
    results = semantic_search(embedding, Keyword.merge(opts, limit: 50))

    {selected, _remaining} =
      Enum.reduce_while(results, {[], max_chars}, fn {memory, score}, {acc, budget} ->
        content_size = String.length(memory.content)

        if content_size <= budget do
          {:cont, {[%{memory: memory, relevance: score} | acc], budget - content_size}}
        else
          {:halt, {acc, budget}}
        end
      end)

    Enum.reverse(selected)
  end

  @doc "Returns the expected embedding dimensions."
  def dimensions, do: @default_dimensions

  # --- Private ---

  defp apply_scope(query, %{tenant_id: tid}) when not is_nil(tid) do
    where(query, [m], m.tenant_id == ^tid)
  end

  defp apply_scope(query, _), do: query

  defp apply_tag_filter(query, nil), do: query
  defp apply_tag_filter(query, tags) when is_list(tags) do
    where(query, [m], fragment("? @> ?", m.tags, ^tags))
  end

  defp apply_kind_filter(query, nil), do: query
  defp apply_kind_filter(query, kind), do: where(query, [m], m.kind == ^kind)
end
