defmodule LoomWeb.StreamController do
  use LoomWeb, :controller

  action_fallback LoomWeb.FallbackController

  def index(conn, _params) do
    streams = Loom.list_sources()
    render(conn, "index.json", streams: streams)
  end
end
