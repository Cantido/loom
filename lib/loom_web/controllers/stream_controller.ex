defmodule LoomWeb.StreamController do
  use LoomWeb, :controller

  alias Loom.Store

  action_fallback LoomWeb.FallbackController

  def index(conn, _params) do
    streams = Store.list_streams(Application.fetch_env!(:loom, :root_dir))
    render(conn, "index.json", streams: streams)
  end
end
