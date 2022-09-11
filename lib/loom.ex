defmodule Loom do
  @moduledoc """
  Loom is an event store database.

  All events are represented by `Cloudevents` structs.

  ## Writing and reading events

  Write a new event to the store with the `append/4` function.
  This will return an `:ok` tuple with the revision number of that event.
  You can then read the event stream with `read/3`, which returns a `Stream` containing the requested events.

      iex> {:ok, event} = Cloudevents.from_map(%{type: "com.example.event", specversion: "1.0", source: "loom", id: "a-uuid"})
      iex> Loom.append(event)
      {:ok, 1}
      iex> Loom.read("loom") |> Enum.at(0) |> Map.get(:id)
      "a-uuid"
  """

  @type stream_id :: String.t()
  @type event_id :: String.t()
  @type event_source :: String.t()
  @type revision :: non_neg_integer()

  @doc """
  Append an event to an event stream.
  """
  @spec append(Cloudevents.t(), Keyword.t()) ::
          {:ok, revision}
          | {:error, :event_exists}
          | {:error, :revision_mismatch}
  def append(event, opts \\ []) do
    case Loom.Store.append(event, opts) do
      {:ok, event} ->
        {:ok, event}
      err ->
        err
    end
  end

  @doc """
  Same as `append/4`, but raises on error.
  """
  def append!(event, opts \\ []) do
    case append(event, opts) do
      {:ok, new_store} -> new_store
      {:error, err} -> raise err
    end
  end

  defdelegate fetch(source, event_id), to: Loom.Store

  @doc """
  Returns the most recent sequence number from a source.
  """
  defdelegate last_sequence(source), to: Loom.Store, as: :last_revision

  defdelegate list_sources, to: Loom.Store, as: :list_streams

  @doc """
  Returns events from a stream.

  ## Options

  - `:direction` - when `:forward`, the first element in the returned list is the earliest event that occurred.
    When `:backward`, the first element is the latest. Default: `:forward`.
  - `:from_revision` - the revision to start the list from, as an integer.
    Can also be `:start`, which starts the list from the earliest revision, or `:end`, which starts the list at the latest.
    You must set this to `:end` when `:direction` is set to `:backwards`. Default: `:start`
  - `:limit` - the maximum number of events to return. Default: `1000`, and cannot be set higher.
  """
  defdelegate read(source, opts \\ []), to: Loom.Store
end
