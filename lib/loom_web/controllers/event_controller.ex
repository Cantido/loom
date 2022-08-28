defmodule LoomWeb.EventController do
  use LoomWeb, :controller

  alias Loom.Store

  action_fallback LoomWeb.FallbackController

  def create(conn, %{"event" => event_params, "stream_id" => stream_id}) do
    with {:ok, event} <- Cloudevents.from_map(event_params),
         {:ok, root_dir} <- Application.fetch_env(:loom, :root_dir),
         {:ok, _revision} <- Store.append(root_dir, stream_id, event)do
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
    {:ok, root_dir} = Application.fetch_env(:loom, :root_dir)
    events = Store.read(root_dir, id) |> Enum.to_list()

    conn
    |> put_resp_content_type("application/cloudevents-batch+json")
    |> render("stream.json", events: events)
  end

  def show(conn, %{"source" => source, "id" => id}) do
    with {:ok, root_dir} <- Application.fetch_env(:loom, :root_dir),
         {:ok, event} <- Store.fetch(root_dir, source, id),
         {:ok, stat} <- Store.stat(root_dir, source, id) do
      etag = Base.encode16(:crypto.hash(:sha256, Cloudevents.to_json(event)))

      if not_modified?(conn, etag, stat.mtime) do
        conn
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> resp(:not_modified, "")
      else
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

  defp not_modified?(conn, etag, last_modified) do
    if_none_match = List.first get_req_header(conn, "if-none-match")
    if_modified_since =
      if if_mod_header = List.first(get_req_header(conn, "if-modified-since")) do
        Timex.parse!(if_mod_header, "{RFC1123}")
      end

    matches_etag? = if_none_match == ~s("#{etag}")
    matches_timestamp? = not is_nil(if_modified_since) and Timex.before?(last_modified, if_modified_since)

    matches_etag? or matches_timestamp?
  end
end
