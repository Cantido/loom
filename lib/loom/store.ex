defmodule Loom.Store do
  @moduledoc """
  Loom's event store.

  Events belong to streams, which are lists of events.
  """
  alias Loom.Event

  import Ecto.Query

  defstruct [streams: %{}]

  def new do
    %__MODULE__{}
  end

  @doc """
  Append an event to an event stream.

  ## Options

  - `:expected_revision` - The current revision of the stream you expect.
  This function will return `{:error, :revision_mismatch}` if the stream's current revision does not match.
  Can be an integer, or `:no_stream`, which asserts that the stream does not exist, or `:stream_exists`, which asserts that a stream with events already exists.

  ## Examples

      iex> event = %Loom.Event{type: "io.github.cantido.myevent"}
      ...> Loom.Store.append("my-stream", event)

      iex> event = %Loom.Event{type: "io.github.cantido.myevent"}
      ...> Loom.Store.append("my-stream", event, expected_revision: 1)
      {:error, :revision_mismatch}
  """
  def append(stream_id, event, opts \\ []) do
    repo = Keyword.get(opts, :repo, Loom.ETS)

    current_revision = last_revision(stream_id, repo: repo)
    expected_revision = Keyword.get(opts, :expected_revision, current_revision)

    if revision_match?(current_revision, expected_revision) do
      next_revision = current_revision + 1
      event = %{event | stream_id: stream_id, revision: next_revision}

      repo.insert(event)
    else
      {:error, :revision_mismatch}
    end
  end

  defp revision_match?(0, :no_stream), do: true
  defp revision_match?(_, :no_stream), do: false
  defp revision_match?(0, :stream_exists), do: false
  defp revision_match?(_, :stream_exists), do: true
  defp revision_match?(x, x), do: true
  defp revision_match?(_, _), do: false

  @doc """
  Same as `append/4`, but raises on error.
  """
  def append!(stream_id, event, opts \\ []) do
    case append(stream_id, event, opts) do
      {:ok, new_store} -> new_store
      {:error, err} -> raise err
    end
  end

  @doc """
  Returns the most recent revision of the stream.

  ## Examples

      iex> event = %Loom.Event{type: "io.github.cantido.myevent"}
      ...> Loom.Store.append!("my-stream", event)
      ...> Loom.Store.last_revision("my-stream")
      1
  """
  def last_revision(stream_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Loom.ETS)

    repo.all(
      from e in Event,
      where: e.stream_id == ^stream_id,
      order_by: [asc: e.revision],
      limit: 1
    )
    |> case do
      [last] -> last.revision
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
      ...> Loom.Store.append!("my-stream", event1)
      ...> Loom.Store.append!("my-stream", event2)
      ...> Loom.Store.read("my-stream") |> Enum.map(&(&1.type))
      ["event-one", "event-two"]
      iex> Loom.Store.read("my-stream", direction: :backward, from_revision: :end) |> Enum.map(&(&1.type))
      ["event-two", "event-one"]
      iex> Loom.Store.read("my-stream", from_revision: 1) |> Enum.map(&(&1.type))
      ["event-two"]

  """
  def read(stream_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Loom.ETS)
    direction = Keyword.get(opts, :direction, :forward)
    from_revision = Keyword.get(opts, :from_revision, :start)

    from(e in Event)
    |> where([e], e.stream_id == ^stream_id)
    |> where_within_revision(direction, from_revision)
    |> order_by_direction(direction)
    |> repo.all()
  end

  defp where_within_revision(query, :forward, :start), do: query
  defp where_within_revision(query, :backward, :end), do: query
  defp where_within_revision(query, direction, from_revision) do
    case direction do
      :forward -> where(query, [e], e.revision > ^from_revision)
      :backward -> where(query, [e], e.revision < ^from_revision)
      end
  end

  defp order_by_direction(query, direction) do
    case direction do
      :forward -> order_by(query, [e], [asc: e.revision])
      :backward -> order_by(query, [e], [desc: e.revision])
    end
  end
end
