defmodule LoomWeb.EventView do
  use LoomWeb, :view
  alias LoomWeb.EventView

  def render("index.json", %{events: events}) do
    render_many(events, EventView, "event.json")
  end

  def render("show.json", %{event: event}) do
    render_one(event, EventView, "event.json")
  end

  def render("event.json", %{event: event}) do
    Loom.Store.Event.to_cloudevent(event)
    |> Cloudevents.to_map()
  end

  def data_size(nil) do
    "0 Bytes"
  end

  def data_size(data) do
    "#{byte_size(data)} Bytes"
  end
end
