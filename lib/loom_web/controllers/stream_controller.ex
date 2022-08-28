defmodule LoomWeb.StreamController do
  use LoomWeb, :controller

  alias Loom.Store

  action_fallback LoomWeb.FallbackController

  def index(conn, _params) do
    streams = Store.list_streams("tmp")
    render(conn, "index.json", streams: streams)
  end
end
