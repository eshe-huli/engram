defmodule Engram.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Core content
      add :content, :text, null: false
      add :summary, :string, size: 1000
      add :kind, :string, null: false, default: "knowledge"

      # Scoping (tenant → fleet → squad → agent)
      add :tenant_id, :binary_id, null: false
      add :fleet_id, :binary_id
      add :squad_id, :binary_id
      add :agent_id, :binary_id
      add :author_id, :string

      # Metadata
      add :tags, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      add :source, :string
      add :confidence, :float, default: 1.0

      # Vector embedding (1536 dimensions — OpenAI ada-002 compatible)
      add :embedding, :vector, size: 1536

      # TTL & access tracking
      add :expires_at, :utc_datetime_usec
      add :last_accessed_at, :utc_datetime_usec
      add :access_count, :integer, default: 0

      # Consolidation
      add :consolidated, :boolean, default: false
      add :consolidated_into_id, :binary_id
      add :consolidation_round, :integer

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    create index(:memories, [:tenant_id])
    create index(:memories, [:tenant_id, :fleet_id])
    create index(:memories, [:tenant_id, :fleet_id, :squad_id])
    create index(:memories, [:kind])
    create index(:memories, [:author_id])
    create index(:memories, [:consolidated])
    create index(:memories, [:expires_at])
    create index(:memories, [:inserted_at])
    create index(:memories, [:tags], using: :gin)

    # Vector similarity index (IVFFlat for approximate nearest neighbor)
    # Note: Requires sufficient data to build. Use exact search initially.
    # execute "CREATE INDEX memories_embedding_idx ON memories USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
  end
end
