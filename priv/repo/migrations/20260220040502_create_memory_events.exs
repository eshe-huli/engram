defmodule Engram.Repo.Migrations.CreateMemoryEvents do
  use Ecto.Migration

  def change do
    create table(:memory_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :memory_id, :binary_id
      add :payload, :map, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:memory_events, [:memory_id])
    create index(:memory_events, [:action])
    create index(:memory_events, [:occurred_at])
  end
end
