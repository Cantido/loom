defmodule LoomWeb.EventController do
  use LoomWeb, :controller

  alias Loom.Store

  action_fallback LoomWeb.FallbackController

  def create(conn, %{"event" => event_params, "stream_id" => stream_id}) do
    with {:ok, event} <- Cloudevents.from_map(event_params),
         {:ok, _revision} <- Store.append("tmp", stream_id, event)do
      conn
      |> put_status(:created)
      #|> put_resp_header("location", Routes.stream_revision_path(conn, :show, event))
      |> render("show.json", event: event)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(LoomWeb.ErrorView)
    |> render(:"422", errors: %{})
  end
end
