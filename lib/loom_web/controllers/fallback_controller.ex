defmodule LoomWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use LoomWeb, :controller

  require Logger

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(LoomWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(LoomWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, error) do
    Logger.error("Unhandled error: #{inspect error, pretty: true}")
    conn
    |> put_status(:internal_server_error)
    |> put_view(LoomWeb.ErrorView)
    |> render(:"500")
  end
end
