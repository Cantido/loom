defmodule LoomWeb.PageController do
  use LoomWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end