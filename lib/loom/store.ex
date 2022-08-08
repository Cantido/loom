defmodule Loom.Store do
  @moduledoc """
  Loom's event store.

  Events belong to streams, which are lists of events.
  """

  defstruct [streams: %{}]

  def new do
    %__MODULE__{}
  end

  @doc """
  Append an event to an event stream.

  ## Examples

      iex> event = %Loom.Event{type: "io.github.cantido.myevent"}
      iex> Loom.Store.new()
      ...> |> Loom.Store.append("my-stream", event)

  """
  def append(store, stream_id, event) do
    next_revision = last_revision(store, stream_id) + 1
    extensions = Map.put(event.extensions, "io.github.cantido.loom.revision", next_revision)
    event = %{event | extensions: extensions}

    stream = Map.get(store.streams, stream_id, [])
    stream = [event | stream]
    %{store |
      streams: Map.put(store.streams, stream_id, stream)
    }
  end

  @doc """
  Returns the most recent revision of the stream.

  ## Examples

      iex> event = %Loom.Event{type: "io.github.cantido.myevent"}
      ...> store = Loom.Store.new()
      ...> |> Loom.Store.append("my-stream", event)
      ...> Loom.Store.last_revision(store, "my-stream")
      1
  """
  def last_revision(store, stream_id) do
    case Map.get(store.streams, stream_id, []) do
      [prev | _rest] -> Map.fetch!(prev.extensions, "io.github.cantido.loom.revision")
      [] -> 0
    end
  end

  @doc """
  Returns events from a stream.

  ## Options

  - `:direction` - when `:forward`, the first element in the returned list is the earliest event that occurred. When `:backward`, the first element is the latest. Default: `:forward`.
  - `:from_revision` - the revision to start the list from, as an integer. Can also be `:start`, which starts the list from the earliest revision, or `:end`, which starts the list at the latest. You must set this to `:end` when `:direction` is set to `:backwards`. Default: `:start`

  ## Examples

      iex> event1 = %Loom.Event{type: "event-one"}
      ...> event2 = %Loom.Event{type: "event-two"}
      ...> store = Loom.Store.new()
      ...> |> Loom.Store.append("my-stream", event1)
      ...> |> Loom.Store.append("my-stream", event2)
      ...> Loom.Store.read(store, "my-stream") |> Enum.map(&(&1.type))
      ["event-one", "event-two"]
      iex> Loom.Store.read(store, "my-stream", direction: :backward, from_revision: :end) |> Enum.map(&(&1.type))
      ["event-two", "event-one"]
      iex> Loom.Store.read(store, "my-stream", from_revision: 1) |> Enum.map(&(&1.type))
      ["event-two"]

  """
  def read(store, stream_id, opts \\ []) do
    events = Map.get(store.streams, stream_id, [])
    from_revision = Keyword.get(opts, :from_revision, :start)

    sort_filter(events, Keyword.get(opts, :direction, :forward), from_revision)
  end

  defp sort_filter(events, :forward, :start), do: Enum.reverse(events)
  defp sort_filter(_events, :forward, :end), do: []
  defp sort_filter(events, :forward, n) when is_integer(n) do
    Enum.reverse(events)
    |> Enum.drop_while(fn event ->
      revision = Map.get(event.extensions, "io.github.cantido.loom.revision")
      revision <= n
    end)
  end
  defp sort_filter(_events, :backward, :start), do: []
  defp sort_filter(events, :backward, :end), do: events
  defp sort_filter(events, :backward, n) when is_integer(n) do
    Enum.drop_while(events, fn event ->
      revision = Map.get(event.extensions, "io.github.cantido.loom.revision")
      revision >= n
    end)
  end
end
