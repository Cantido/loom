defmodule LoomWeb.EventController do
  use LoomWeb, :controller

  alias Loom.Store

  require Logger

  action_fallback LoomWeb.FallbackController

  def create(conn, params) do
    team = Map.get_lazy(conn.assigns, :current_team, fn -> Loom.Accounts.get_team!(params["team_id"]) end)

    source_value = Map.get(params, "source", params["source_id"])

    {:ok, source} = Store.fetch_source(source_value)

    event_params =
      if Map.has_key?(params, "event") do
        params["event"]
      else
        params
      end

    event_params = Enum.reject(event_params, fn {_key, val} -> val == "" end) |> Map.new()

    with {:ok, event} <- Loom.append(event_params, team) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.source_event_path(conn, :show, event.source, event.id)
      )
      |> render(:show, team: source.team, source: source, event: event)
    end
  end

  def new(conn, %{"source_id" => id}) do
    {:ok, source} = Loom.Store.fetch_source(id)
    changeset = Store.new_event_changeset(source)
    render(conn, "new.html", team: source.team, source: source, changeset: changeset)
  end

  def index(conn, %{"source_id" => id} = params) do
    {:ok, source} = Loom.Store.fetch_source(id)

    opts = parse_sequence_opts(params)

    events = Loom.read(source.source, source.team, opts) |> Enum.to_list()

    conn
    |> render(:index, team: source.team, source: source, events: events)
  end


  defp parse_sequence_opts(params) do
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
  end

  def show(conn, %{"source_id" => source_id, "id" => id}) do
    with {:ok, source} <- Loom.Store.fetch_source(source_id),
         {:ok, event} <- Loom.fetch(source_id, id, source.team) do
      etag = Base.encode16(:crypto.hash(:sha256, Cloudevents.to_json(event)))

      if not_modified?(conn, etag, event.time) do
        conn
        |> put_cache_control()
        |> resp(:not_modified, "")
      else
        last_modified = Timex.format!(event.time, "{RFC1123z}")

        conn
        |> put_status(:ok)
        |> put_resp_header("etag", ~s("#{etag}"))
        |> put_resp_header("last-modified", last_modified)
        |> put_cache_control()
        |> render(:show, team: source.team, source: source, event: event)
      end
    end
  end

  defp put_cache_control(conn) do
    # I want the HTML version of the page to have a much lower cache time because other things besides the event may change
    case get_format(conn) do
      "json" ->
        put_resp_header(conn, "cache-control", "public, max-age=31536000, immutable")

      "html" ->
        put_resp_header(conn, "cache-control", "public, max-age=86400, immutable")
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
