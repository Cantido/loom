defmodule Loom.Store.EventQueries do
  @moduledoc """
  Queries for `Event`s.
  """

  use Timex

  alias Loom.Store.Event

  import Ecto.Query



  def query_by_sequence(source_name, opts) do
    direction = Keyword.get(opts, :direction, :forward)
    from_revision = Keyword.get(opts, :from_revision, :start)
    limit = Keyword.get(opts, :limit, 1_000) |> min(1_000)

    revision_range =
      case {direction, from_revision} do
        {:forward, :end} ->
          []

        {:forward, :start} ->
          1..limit

        {:forward, range_start} ->
          range_end = range_start + limit
          range_start..range_end

        {:backward, :start} ->
          []

        {:backward, :end} ->
          limit..0

        {:backward, range_start} ->
          range_end = range_start - limit
          range_start..range_end
      end
      |> Enum.map(&Integer.to_string/1)

    sort_dir =
      case direction do
        :forward -> :asc
        :backward -> :desc
      end

    from event in Event,
      join: source in assoc(event, :source),
      where: source.source == ^source_name,
      where: event.extensions["sequence"] in ^revision_range,
      order_by: [{^sort_dir, event.extensions["sequence"]}]
  end

  def query_by_time(source, opts \\ []) do
    stop_time = Keyword.get(opts, :stop_time, DateTime.utc_now())
    start_time =
      if start_time = Keyword.get(opts, :start_time) do
        start_time
      else
        duration = Keyword.get(opts, :duration, Duration.from_minutes(2))
        Timex.subtract(stop_time, duration)
      end

    from event in Event,
      join: source in assoc(event, :source),
      where: source.source == ^source,
      where: event.time < ^stop_time,
      where: event.time >= ^start_time
  end
end
