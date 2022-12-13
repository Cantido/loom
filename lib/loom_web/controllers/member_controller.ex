defmodule LoomWeb.MemberController do
  use LoomWeb, :controller

  alias Loom.Accounts

  def index(conn, %{"team_id" => team_id}) do
    team = Accounts.get_team!(team_id)

    render(conn, :index, team: team, users: team.users)
  end
end
