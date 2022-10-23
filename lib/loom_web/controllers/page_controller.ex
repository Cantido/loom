defmodule LoomWeb.PageController do
  use LoomWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: Routes.team_path(conn, :index))
  end
end
