defmodule Engram.Events do
  @moduledoc """
  Event sourcing for memory operations.

  Every memory write is recorded as an immutable event for audit trails
  and potential replay. Events are also broadcast via PubSub for
  real-time subscriptions.
  """

  import Ecto.Query
  alias Engram.Repo
  alias Engram.Events.MemoryEvent

  @doc "Emit an event for a memory operation."
  def emit(action, data) when is_atom(action) do
    attrs = %{
      action: to_string(action),
      memory_id: extract_id(data),
      payload: serialize(data),
      occurred_at: DateTime.utc_now()
    }

    %MemoryEvent{}
    |> MemoryEvent.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, event} ->
        broadcast(event)
        {:ok, event}

      error ->
        error
    end
  end

  @doc "List events for a memory."
  def list_events(memory_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    from(e in MemoryEvent,
      where: e.memory_id == ^memory_id,
      order_by: [desc: e.occurred_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc "List all events in a time range."
  def list_events_in_range(from_dt, to_dt, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)

    from(e in MemoryEvent,
      where: e.occurred_at >= ^from_dt and e.occurred_at <= ^to_dt,
      order_by: [asc: e.occurred_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  # --- Private ---

  defp extract_id(%{id: id}), do: id
  defp extract_id(%{memory_id: id}), do: id
  defp extract_id(_), do: nil

  defp serialize(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp serialize(data) when is_map(data) do
    data
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp broadcast(event) do
    Phoenix.PubSub.broadcast(
      Engram.PubSub,
      "memories:events",
      {:memory_event, event}
    )
  end
end
