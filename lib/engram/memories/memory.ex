defmodule Engram.Memories.Memory do
  @moduledoc """
  Schema for a memory — the fundamental unit of knowledge in Engram.

  A memory stores content with rich metadata, scoping, tags, and
  an optional vector embedding for semantic search.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @memory_kinds ~w(knowledge observation decision discovery error context consolidated)

  schema "memories" do
    # Core content
    field :content, :string
    field :summary, :string
    field :kind, :string, default: "knowledge"

    # Scoping (tenant → fleet → squad → agent)
    field :tenant_id, :binary_id
    field :fleet_id, :binary_id
    field :squad_id, :binary_id
    field :agent_id, :binary_id
    field :author_id, :string

    # Metadata
    field :tags, {:array, :string}, default: []
    field :metadata, :map, default: %{}
    field :source, :string
    field :confidence, :float, default: 1.0

    # Vector embedding for semantic search (pgvector)
    field :embedding, {:array, :float}

    # TTL & access tracking
    field :expires_at, :utc_datetime_usec
    field :last_accessed_at, :utc_datetime_usec
    field :access_count, :integer, default: 0

    # Consolidation tracking
    field :consolidated, :boolean, default: false
    field :consolidated_into_id, :binary_id
    field :consolidation_round, :integer

    timestamps()
  end

  @required_fields ~w(content tenant_id)a
  @optional_fields ~w(
    summary kind fleet_id squad_id agent_id author_id
    tags metadata source confidence embedding
    expires_at consolidated consolidated_into_id consolidation_round
  )a

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:kind, @memory_kinds)
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_length(:content, min: 1, max: 100_000)
    |> validate_length(:summary, max: 1_000)
    |> validate_length(:tags, max: 50)
  end

  def access_changeset(memory, attrs) do
    cast(memory, attrs, [:last_accessed_at, :access_count])
  end

  @doc "Returns the list of valid memory kinds."
  def kinds, do: @memory_kinds
end
