defmodule Loom.Store do
  @moduledoc """
  Loom's event store.

  All events are represented by `Cloudevents` structs.

  ## Writing and reading events

  Write a new event to the store with the `append/4` function.
  This will return an `:ok` tuple with the revision number of that event.
  You can then read the event stream with `read/3`, which returns a `Stream` containing the requested events.

      iex> {:ok, event} = Cloudevents.from_map(%{type: "com.example.event", specversion: "1.0", source: "loom", id: "a-uuid"})
      iex> Loom.Store.append(event)
      {:ok, 1}
      iex> Loom.Store.read("loom") |> Enum.at(0) |> Map.get(:id)
      "a-uuid"

  """
  use Nebulex.Caching

  alias Loom.Event
  alias Loom.Repo

  import Ecto.Query

  require Logger

  @type stream_id :: String.t()
  @type event_id :: String.t()
  @type event_source :: String.t()
  @type revision :: non_neg_integer()

  def init(_), do: nil
  def delete_all(_), do: nil

  @doc """
  Append an event to an event stream.
  """
  @spec append(Cloudevents.t(), Keyword.t()) :: {:ok, revision} | {:error, :revision_mismatch} | {:error, :retry_limit_reached}
  def append(event, opts \\ []) do
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:last_sequence, fn repo, _changes ->
        query = from e in Event, where: e.source == ^event.source
        all_seq = repo.all(query) |> Enum.map(&(String.to_integer(Map.get(&1.extensions, "sequence", "0"))))

        max_seq = if Enum.empty?(all_seq), do: 0, else: Enum.max(all_seq)

        if revision_match?(max_seq, Keyword.get(opts, :expected_revision, :any)) do
          {:ok, max_seq}
        else
          {:error, :revision_mismatch}
        end
      end)
      |> Ecto.Multi.insert(:event, fn %{last_sequence: last_rev} ->
        next_rev = Integer.to_string(last_rev + 1)
        extensions = Map.put(event.extensions, "sequence", next_rev)
        event = %{event | extensions: extensions}
        event = if is_nil(event.time), do: %{event | time: DateTime.utc_now()}, else: event

        Loom.Event.from_cloudevent(event)
      end)
      |> Ecto.Multi.run(:webhook, fn _, %{event: event} ->
        event = Event.to_cloudevent(event)
        Loom.Subscriptions.send_webhooks(event, event.source, event.extensions["sequence"])
        LoomWeb.Endpoint.broadcast!("stream:" <> event.source, "event", event)
        {:ok, nil}
      end)
      |> Repo.transaction()

    case result do
      {:ok, results} ->
        {:ok, String.to_integer(results[:event].extensions["sequence"])}
      {:error, :last_sequence, :revision_mismatch, _changes} ->
        {:error, :revision_mismatch}
    end
  end

  defp revision_match?(_, :any), do: true
  defp revision_match?(0, :no_stream), do: true
  defp revision_match?(_, :no_stream), do: false
  defp revision_match?(0, :stream_exists), do: false
  defp revision_match?(_, :stream_exists), do: true
  defp revision_match?(x, x), do: true
  defp revision_match?(_, _), do: false

  @doc """
  Same as `append/4`, but raises on error.
  """
  def append!(event, opts \\ []) do
    case append(event, opts) do
      {:ok, new_store} -> new_store
      {:error, err} -> raise err
    end
  end

  @doc """
  Returns the most recent revision of the stream.
  """
  def last_revision(source, _opts \\ []) do
    query = from e in Event, where: e.source == ^source, select: coalesce(e.extensions["sequence"], "0")
    all_seq = Repo.all(query) |> Enum.map(&String.to_integer/1)

    if Enum.empty?(all_seq), do: 0, else: Enum.max(all_seq)
  end

  def fetch(source, event_id) do
    if event = Repo.get_by(Event, source: source, id: event_id) do
      {:ok, Event.to_cloudevent(event)}
    else
      {:error, :not_found}
    end
  end

  def list_streams do
    query = from e in Event, order_by: e.source, select: e.source
    Repo.all(query)
  end

  @doc """
  Returns events from a stream.

  ## Options

  - `:direction` - when `:forward`, the first element in the returned list is the earliest event that occurred. When `:backward`, the first element is the latest. Default: `:forward`.
  - `:from_revision` - the revision to start the list from, as an integer. Can also be `:start`, which starts the list from the earliest revision, or `:end`, which starts the list at the latest. You must set this to `:end` when `:direction` is set to `:backwards`. Default: `:start`
  - `:limit` - the maximum number of events to return. Default: `1000`, and cannot be set higher.
  """
  def read(stream_id, opts \\ []) do
    direction = Keyword.get(opts, :direction, :forward)
    from_revision = Keyword.get(opts, :from_revision, :start)
    limit = Keyword.get(opts, :limit, 1_000) |> min(1_000)

    revision_range =
      case {direction, from_revision} do
        {:forward, :end} -> []
        {:forward, :start} ->
          range_end = min(last_revision(stream_id), limit)
          1..range_end
        {:forward, range_start} ->
          range_end = min(last_revision(stream_id), range_start + limit)
          range_start..range_end
        {:backward, :start} -> []
        {:backward, :end} ->
          range_start = min(last_revision(stream_id), limit)
          range_start..0
        {:backward, range_start} ->
          range_end = max(last_revision(stream_id), range_start - limit)
          range_start..range_end
      end
      |> Enum.map(&Integer.to_string/1)

    Repo.all(from e in Event, where: e.source == ^stream_id, where: e.extensions["sequence"] in ^revision_range, order_by: e.extensions["sequence"])
    |> Enum.map(&Event.to_cloudevent/1)
  end
end
