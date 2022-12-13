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
end
