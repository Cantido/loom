defmodule LoomWeb.TeamView do
  use LoomWeb, :view

  def is_owner?(user, team) do
    Loom.Accounts.Team.get_role(team, user).role == :owner
  end
end
