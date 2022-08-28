defmodule LoomWeb.EventController do
  use LoomWeb, :controller

  alias Loom.Store

  action_fallback LoomWeb.FallbackController

  def create(conn, %{"event" => event_params, "stream_id" => stream_id}) do
    with {:ok, event} <- Cloudevents.from_map(event_params),
         {:ok, _revision} <- Store.append("tmp", stream_id, event)do
      conn
      |> put_status(:created)
      |> put_resp_content_type("application/cloudevents+json")
      |> put_resp_header("location", Routes.event_path(conn, :show, event.source, event.id))
      |> render("show.json", event: event)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(LoomWeb.ErrorView)
    |> render(:"422", errors: %{})
  end

  def stream(conn, %{"stream_id" => id}) do
    events = Store.read("tmp", id) |> Enum.to_list()

    conn
    |> put_resp_content_type("application/cloudevents-batch+json")
    |> render("stream.json", events: events)
  end

  def show(conn, %{"source" => source, "id" => id}) do
    with {:ok, event} <- Store.fetch("tmp", source, id),
         {:ok, stat} <- Store.stat("tmp", source, id) do
      etag = Base.encode16(:crypto.hash(:sha256, Cloudevents.to_json(event)))
      last_modified = Timex.format!(stat.mtime, "{RFC1123z}")
      conn
      |> put_status(:ok)
      |> put_resp_content_type("application/cloudevents+json")
      |> put_resp_header("etag", ~s("#{etag}"))
      |> put_resp_header("last-modified", last_modified)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> render("show.json", event: event)
    end
  end
end
