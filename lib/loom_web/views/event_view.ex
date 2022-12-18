defmodule LoomWeb.EventView do
  use LoomWeb, :view
  alias LoomWeb.EventView

  def render("index.json", %{events: events}) do
    render_many(events, EventView, "event.json")
  end

  def render("index.json-cloudevents-batch", %{events: events}) do
    render_many(events, EventView, "event.json")
  end

  def render("show.json", %{event: event}) do
    render_one(event, EventView, "event.json")
  end

  def render("show.json-cloudevents", %{event: event}) do
    render_one(event, EventView, "event.json")
  end

  def render("event.json", %{event: event}) do
    Cloudevents.to_map(event)
  end

  def render("event.json-cloudevents", %{event: event}) do
    Cloudevents.to_map(event)
  end

  def data_size(nil) do
    byte_size_to_string(0)
  end

  def data_size(data) do
    byte_size_to_string(byte_size(data))
  end

  defp byte_size_to_string(size) do
    Cldr.Unit.to_string! size, unit: :kibibyte
  end
end
