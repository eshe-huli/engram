defmodule EngramWeb.FallbackController do
  use EngramWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn |> put_status(:not_found) |> json(%{error: "Not found"})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

    conn |> put_status(:unprocessable_entity) |> json(%{error: "Validation failed", details: errors})
  end

  def call(conn, {:error, reason}) do
    conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
  end
end
