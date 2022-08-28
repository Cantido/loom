defmodule LoomWeb.EventView do
  use LoomWeb, :view
  alias LoomWeb.EventView

  def render("index.json", %{events: events}) do
    render_many(events, EventView, "event.json")
  end

  def render("stream.json", %{events: events}) do
    render_many(events, EventView, "event.json")
  end

  def render("show.json", %{event: event}) do
    render_one(event, EventView, "event.json")
  end

  def render("event.json", %{event: event}) do
    Cloudevents.to_map(event)
  end
end
