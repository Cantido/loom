defmodule LoomWeb.EventView do
  use LoomWeb, :view
  alias LoomWeb.EventView
  alias Explorer.DataFrame
  require Explorer.DataFrame
  require Logger

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

  def chart(assigns) do
    end_time = DateTime.utc_now() |> DateTime.truncate(:second)
    start_time = DateTime.add(end_time, -2, :minute)

    events_per_second =
      if Enum.empty?(assigns.events) do
        empty_data(start_time, end_time)
      else
        Enum.map(assigns.events, fn e ->
          naive_time = DateTime.to_naive(e.time)
          time_group = NaiveDateTime.truncate(naive_time, :second)

          e
          |> Map.from_struct()
          |> Map.take([:id, :time])
          |> Map.put(:time, naive_time)
          |> Map.put(:time_group, time_group)
        end)
        |> DataFrame.new()
        |> DataFrame.group_by(:time_group)
        |> DataFrame.summarise(count: count(id))
        |> fill_missing(start_time, end_time)
        |> DataFrame.arrange(time_group)
        end

    svg =
      events_per_second
      |> DataFrame.to_rows()
      |> Contex.Dataset.new()
      |> Contex.Plot.new(Contex.LinePlot, 800, 400, mapping: %{x_col: "time_group", y_cols: ["count"]}, smoothed: false)
      |> Contex.Plot.to_svg()

    assigns = Map.put(assigns, :svg, svg)

    ~H"""
    <%= @svg %>
    """
  end

  defp fill_missing(df, start_datetime, stop_datetime) do
    timestamps = datetime_range(start_datetime, stop_datetime)

    DataFrame.new(time_group: timestamps)
    |> DataFrame.join(df, how: :left)
    |> DataFrame.mutate_with(&[count: Explorer.Series.fill_missing(&1["count"], 0)])
  end

  defp empty_data(start_datetime, stop_datetime) do
    datetime_range(start_datetime, stop_datetime)
    |> Enum.map(fn datetime ->
      %{
        time_group: datetime,
        count: 0
      }
    end)
    |> DataFrame.new()
  end

  defp datetime_range(start_datetime, stop_datetime) do
    Stream.iterate(start_datetime, &DateTime.add(&1, 1, :second))
    |> Stream.take_while(&DateTime.compare(&1, stop_datetime) in [:lt, :eq])
    |> Stream.map(&DateTime.to_naive/1)
    |> Enum.to_list()
  end
end
