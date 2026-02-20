defmodule EngramWeb.HealthController do
  use EngramWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", service: "engram", version: "0.1.0"})
  end
end
