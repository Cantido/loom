defmodule LoomWeb.AuthErrorHandler do
  import Plug.Conn

  require Logger

  @behaviour Guardian.Plug.ErrorHandler

  @impl true
  def auth_error(conn, {:unauthorized, reason}, _opts) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.json(%{
      error: "invalid_client",
      error_description: reason
    })
  end

  @impl true
  def auth_error(conn, {:no_resource_found, reason}, _opts) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.json(%{
      error: "invalid_client",
      error_description: reason
    })
  end

  @impl true
  def auth_error(conn, {:unauthenticated, reason}, _opts) do
    conn
    |> put_status(403)
    |> Phoenix.Controller.json(%{
      error: "forbidden",
      error_description: "You must authenticate to access this resource"
    })
  end
end
