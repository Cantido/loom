defmodule LoomWeb.SourceController do
  use LoomWeb, :controller

  action_fallback LoomWeb.FallbackController

  def index(conn, %{"team_id" => team_id}) do
    sources = Loom.Accounts.get_team!(team_id).sources |> Enum.map(&(&1.source))
    render(conn, :index, sources: sources)
  end
end
