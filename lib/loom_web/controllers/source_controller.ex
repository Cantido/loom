defmodule LoomWeb.SourceController do
  use LoomWeb, :controller

  action_fallback LoomWeb.FallbackController

  def index(conn, _params) do
    streams = conn.assigns[:current_team].sources |> Enum.map(&(&1.source))
    render(conn, "index.json", streams: streams)
  end
end
