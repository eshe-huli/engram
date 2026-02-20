defmodule Engram.Scoping do
  @moduledoc """
  Multi-tenant memory scoping.

  Enforces isolation at four levels: Tenant → Fleet → Squad → Agent.
  Every API request must include at least a tenant_id.
  """

  @type scope :: %{
          tenant_id: String.t(),
          fleet_id: String.t() | nil,
          squad_id: String.t() | nil,
          agent_id: String.t() | nil
        }

  @doc "Extracts scope from connection params or API key."
  def extract_scope(params) do
    %{
      tenant_id: params["tenant_id"],
      fleet_id: params["fleet_id"],
      squad_id: params["squad_id"],
      agent_id: params["agent_id"]
    }
  end

  @doc "Validates that required scope fields are present."
  def validate_scope(%{tenant_id: nil}), do: {:error, :tenant_required}
  def validate_scope(%{tenant_id: _} = scope), do: {:ok, scope}
  def validate_scope(_), do: {:error, :invalid_scope}

  @doc "Checks if `accessor` scope can read from `target` scope."
  def can_access?(accessor, target) do
    accessor.tenant_id == target.tenant_id &&
      (is_nil(accessor.fleet_id) || accessor.fleet_id == target.fleet_id) &&
      (is_nil(accessor.squad_id) || accessor.squad_id == target.squad_id) &&
      (is_nil(accessor.agent_id) || accessor.agent_id == target.agent_id)
  end
end
