defmodule LoomWeb.StreamController do
  use LoomWeb, :controller

  alias Loom.Store

  action_fallback LoomWeb.FallbackController

  def index(conn, _params) do
    streams = Store.list_streams("tmp")
    render(conn, "index.json", streams: streams)
  end

  def show(conn, %{"id" => id}) do
    events = Store.read("tmp", id) |> Enum.to_list()

    conn
    |> put_resp_content_type("application/cloudevents-batch+json")
    |> render("show.json", events: events)
  end
end
