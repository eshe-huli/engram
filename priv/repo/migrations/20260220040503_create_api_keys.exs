defmodule Engram.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :key_hash, :string, null: false
      add :active, :boolean, default: true

      # Scope
      add :tenant_id, :binary_id, null: false
      add :fleet_id, :binary_id
      add :squad_id, :binary_id
      add :agent_id, :binary_id

      # Metadata
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:tenant_id])
    create index(:api_keys, [:active])
  end
end
