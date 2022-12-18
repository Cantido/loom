defmodule LoomWeb.SourceController do
  use LoomWeb, :controller

  require Logger

  action_fallback LoomWeb.FallbackController

  def index(conn, params) do
    team = get_team(conn, params)
    sources = team.sources

    event_counts = Loom.last_sequences(team)

    render(conn, :index, team: team, sources: sources, event_counts: event_counts)
  end

  def new(conn, params) do
    team = get_team(conn, params)
    changeset = Ecto.Changeset.change(Ecto.build_assoc(team, :sources))

    render(conn, :new, changeset: changeset, team: team)
  end

  def create(conn, %{"source" => %{"source" => source_name}} = params) do
    team = get_team(conn, params)

    {:ok, source} = Loom.Store.create_source(team, source_name)

    # gotta fetch the team again so we authorize last_sequence with a fresh list of teams
    team = get_team(conn, params)
    last_sequence = Loom.last_sequence(source.source, team)

    conn
    |> put_status(:created)
    |> render(:show, team: team, source: source, last_sequence: last_sequence)
  end

  def show(conn, %{"id" => id} = params) do
    team = get_team(conn, params)
    source = Loom.Store.get_source!(id)
    last_sequence = Loom.last_sequence(source.source, team)
    render(conn, :show, team: team, source: source, last_sequence: last_sequence)
  end

  def delete(conn, %{"id" => id} = params) do
    team = get_team(conn, params)
    source = Loom.Store.get_source!(id)

    case Loom.delete_source(source.source, team) do
      :ok ->
        case get_format(conn) do
          "html" ->
            conn
            |> put_flash(:success, gettext("Source \"%{source}\" successfully deleted.", source: source.source))
            |> redirect(to: Routes.team_source_path(conn, :index, team))
          "json" ->
            conn
            |> put_status(:no_content)
            |> render(:delete)
        end
      err ->
        Logger.error("Could not delete source #{id} (source value: #{source.source}) due to error: #{inspect err}")
        case get_format(conn) do
          "html" ->
            conn
            |> put_flash(:danger, gettext("Source \"%{source}\" could not be deleted due to an unexpected issue.", source: source.source))
            |> redirect(to: Routes.team_source_path(conn, :index, team))
          "json" ->
            conn
            |> put_status(:internal_server_error)
            |> render(:error)
        end
    end
  end

  defp get_team(conn, params) do
    Map.get_lazy(conn.assigns, :current_team, fn -> Loom.Accounts.get_team!(params["team_id"]) end)
  end
end
