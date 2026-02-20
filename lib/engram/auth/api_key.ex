defmodule Engram.Auth.ApiKey do
  @moduledoc "Schema for API keys with scoped access."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "api_keys" do
    field :name, :string
    field :key_hash, :string
    field :active, :boolean, default: true

    # Scope
    field :tenant_id, :binary_id
    field :fleet_id, :binary_id
    field :squad_id, :binary_id
    field :agent_id, :binary_id

    # Metadata
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(key, attrs) do
    key
    |> cast(attrs, ~w(name key_hash active tenant_id fleet_id squad_id agent_id expires_at last_used_at)a)
    |> validate_required(~w(name key_hash tenant_id)a)
    |> unique_constraint(:key_hash)
  end
end
