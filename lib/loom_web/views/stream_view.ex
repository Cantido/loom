defmodule LoomWeb.StreamView do
  use LoomWeb, :view
  alias LoomWeb.EventView
  alias LoomWeb.StreamView

  def render("index.json", %{streams: streams}) do
    %{data: render_many(streams, StreamView, "stream.json")}
  end

  def render("stream.json", %{stream: stream}) do
    stream
  end

  def render("show.json", %{events: events}) do
    render_many(events, EventView, "event.json")
  end
end
