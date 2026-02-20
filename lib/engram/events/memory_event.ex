defmodule Engram.Events.MemoryEvent do
  @moduledoc """
  Schema for memory events — immutable audit trail entries.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "memory_events" do
    field :action, :string
    field :memory_id, :binary_id
    field :payload, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    timestamps(updated_at: false)
  end

  @required ~w(action occurred_at)a
  @optional ~w(memory_id payload)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:action, ~w(
      memory_created memory_updated memory_deleted
      memory_accessed memory_consolidated
    ))
  end
end
