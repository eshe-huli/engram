defmodule EngramWeb.Plugs.Authenticate do
  @moduledoc "Plug to authenticate API requests via Bearer token."

  import Plug.Conn
  alias Engram.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> key] <- get_req_header(conn, "authorization"),
         {:ok, scope} <- Auth.validate_key(key) do
      conn
      |> assign(:scope, scope)
      |> assign(:authenticated, true)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid or missing API key"})
        |> halt()
    end
  end
end
