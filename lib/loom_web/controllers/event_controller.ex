defmodule LoomWeb.EventController do
  use LoomWeb, :controller

  action_fallback LoomWeb.FallbackController

  def create(conn, event_params) do
    case Loom.append(event_params, conn.assigns[:current_team]) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> put_resp_content_type("application/cloudevents+json")
        |> put_resp_header("location", Routes.source_event_path(conn, :show, event.source.source, event.id))
        |> render("show.json", event: event)
      err -> err
    end
  end

  def index(conn, %{"source_id" => id} = params) do
    opts =
      Map.take(params, ["limit", "from_revision", "direction"])
      |> Map.new(fn {k, v} ->
        {String.to_existing_atom(k), v}
      end)
      |> Map.update(:limit, 100, &String.to_integer/1)
      |> Map.update(:from_revision, :start, fn rev ->
        if rev in ["start", "end"] do
          String.to_existing_atom(rev)
        else
          String.to_integer(rev)
        end
      end)
      |> Map.update(:direction, :forward, fn dir ->
        String.to_existing_atom(dir)
      end)
      |> Enum.to_list()

    events = Loom.read(id, conn.assigns[:current_team], opts) |> Enum.to_list()

    conn
    |> put_resp_content_type("application/cloudevents-batch+json")
    |> render("stream.json", events: events)
  end

  def show(conn, %{"source_id" => source, "id" => id}) do
    with {:ok, event} <- Loom.fetch(source, id, conn.assigns[:current_team]) do
      etag = Base.encode16(:crypto.hash(:sha256, Cloudevents.to_json(Loom.Store.Event.to_cloudevent(event))))

      if not_modified?(conn, etag, event.time) do
        conn
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> resp(:not_modified, "")
      else
        last_modified = Timex.format!(event.time, "{RFC1123z}")

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
    if_none_match = List.first(get_req_header(conn, "if-none-match"))

    if_modified_since =
      if if_mod_header = List.first(get_req_header(conn, "if-modified-since")) do
        Timex.parse!(if_mod_header, "{RFC1123}")
      end

    matches_etag? = if_none_match == ~s("#{etag}")

    matches_timestamp? =
      not is_nil(if_modified_since) and Timex.before?(last_modified, if_modified_since)

    matches_etag? or matches_timestamp?
  end
end
