defmodule Engram.Auth do
  @moduledoc """
  API key authentication.

  Validates API keys and extracts the associated scope.
  Can delegate to RingForge auth or operate standalone.
  """

  import Ecto.Query
  alias Engram.Repo
  alias Engram.Auth.ApiKey

  @doc "Validates an API key and returns the associated scope."
  def validate_key(key_string) when is_binary(key_string) do
    hash = hash_key(key_string)

    case Repo.one(from k in ApiKey, where: k.key_hash == ^hash and k.active == true) do
      nil ->
        {:error, :invalid_key}

      %ApiKey{expires_at: exp} = key when not is_nil(exp) ->
        if DateTime.compare(exp, DateTime.utc_now()) == :gt do
          touch_used(key)
          {:ok, key_to_scope(key)}
        else
          {:error, :expired_key}
        end

      %ApiKey{} = key ->
        touch_used(key)
        {:ok, key_to_scope(key)}
    end
  end

  @doc "Creates a new API key."
  def create_key(attrs) do
    raw_key = generate_key()
    hash = hash_key(raw_key)

    %ApiKey{}
    |> ApiKey.changeset(Map.put(attrs, :key_hash, hash))
    |> Repo.insert()
    |> case do
      {:ok, key} -> {:ok, key, raw_key}
      error -> error
    end
  end

  @doc "Revokes an API key."
  def revoke_key(key_id) do
    case Repo.get(ApiKey, key_id) do
      nil -> {:error, :not_found}
      key -> key |> ApiKey.changeset(%{active: false}) |> Repo.update()
    end
  end

  # --- Private ---

  defp generate_key do
    "eng_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  defp hash_key(key) do
    :crypto.hash(:sha256, key) |> Base.encode16(case: :lower)
  end

  defp key_to_scope(key) do
    %{
      tenant_id: key.tenant_id,
      fleet_id: key.fleet_id,
      squad_id: key.squad_id,
      agent_id: key.agent_id
    }
  end

  defp touch_used(key) do
    key
    |> ApiKey.changeset(%{last_used_at: DateTime.utc_now()})
    |> Repo.update()
  end
end
