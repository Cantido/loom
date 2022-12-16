defmodule LoomWeb.SourceController do
  use LoomWeb, :controller

  require Logger

  action_fallback LoomWeb.FallbackController

  def index(conn, %{"team_id" => team_id}) do
    team = Loom.Accounts.get_team!(team_id)
    sources = team.sources

    event_counts = Loom.last_sequences(team)

    render(conn, :index, team: team, sources: sources, event_counts: event_counts)
  end

  def new(conn, %{"team_id" => team_id}) do
    team = Loom.Accounts.get_team!(team_id)
    changeset = Ecto.Changeset.change(Ecto.build_assoc(team, :sources))

    render(conn, "new.html", changeset: changeset, team: team)
  end

  def create(conn, %{"team_id" => team_id, "source" => %{"source" => source_name}}) do
    team = Loom.Accounts.get_team!(team_id)

    {:ok, source} = Loom.Store.create_source(team, source_name)

    # gotta fetch the team again so we authorize last_sequence with a fresh list of teams
    team = Loom.Accounts.get_team!(team_id)
    last_sequence = Loom.last_sequence(source.source, team)

    conn
    |> put_status(:created)
    |> render(:show, team: team, source: source, last_sequence: last_sequence)
  end

  def show(conn, %{"team_id" => team_id, "id" => id}) do
    team = Loom.Accounts.get_team!(team_id)
    source = Loom.Store.get_source!(id)
    last_sequence = Loom.last_sequence(source.source, team)
    render(conn, :show, team: team, source: source, last_sequence: last_sequence)
  end

  def delete(conn, %{"team_id" => team_id, "id" => id}) do
    team = Loom.Accounts.get_team!(team_id)
    source = Loom.Store.get_source!(id)

    case Loom.delete_source(source.source, team) do
      :ok ->
        conn
        |> put_flash(:info, gettext("Source \"%{source}\" successfully deleted.", source: source.source))
        |> redirect(to: Routes.team_source_path(conn, :index, team))
      err ->

        Logger.error("Could not delete source #{id} (source value: #{source.source}) due to error: #{inspect err}")
        conn
        |> put_flash(:warning, gettext("Source \"%{source}\" could not be deleted due to an unexpected issue.", source: source.source))
        |> redirect(to: Routes.team_source_path(conn, :index, team))
    end
  end
end
