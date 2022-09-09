defmodule Loom.Store do
  @moduledoc """
  Loom's event store.

  Events belong to streams, which are lists of events, usually correlating to a specific aggregate.

  All events are represented by `Cloudevents` structs.

  ## Writing and reading events

  Write a new event to the store with the `append/4` function.
  This will return an `:ok` tuple with the revision number of that event.
  You can then read the event stream with `read/3`, which returns a `Stream` containing the requested events.

      iex> root_dir = System.tmp_dir!() |> Path.join(to_string(:rand.uniform(1_000_000)))
      iex> Loom.Store.init(root_dir)
      iex> {:ok, event} = Cloudevents.from_map(%{type: "com.example.event", specversion: "1.0", source: "loom", id: "a-uuid"})
      iex> Loom.Store.append(root_dir, "loom", event)
      {:ok, 1}
      iex> Loom.Store.read(root_dir, "loom") |> Enum.at(0) |> Map.get(:id)
      "a-uuid"

  ```

  In this directory, we have two event sources, `my-source-1` and `my-source-2`,
  and four streams, `$all`, `my-stream-1`, `my-stream-2`, and `my-stream-3`.

  Navigate the event store's filesystem using these functions:

  - `events_path/1`
  - `event_source_path/2`
  - `event_path/3`
  - `event_path_for_revision/3`
  - `streams_path/1`
  - `stream_path/2`
  - `stream_revision_path/3`
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
  @spec append(Path.t(), stream_id(), Cloudevents.t(), Keyword.t()) :: {:ok, revision} | {:error, :revision_mismatch} | {:error, :retry_limit_reached}
  def append(_dir, stream_id, event, opts \\ []) do
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
        LoomWeb.Endpoint.broadcast!("stream:" <> stream_id, "event", event)
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
  def append!(root_dir, stream_id, event, opts \\ []) do
    case append(root_dir, stream_id, event, opts) do
      {:ok, new_store} -> new_store
      {:error, err} -> raise err
    end
  end

  @doc """
  Returns the most recent revision of the stream.
  """
  def last_revision(_dir, stream_id, _opts \\ []) do
    query = from e in Event, where: e.source == ^stream_id, select: coalesce(e.extensions["sequence"], "0")
    all_seq = Repo.all(query) |> Enum.map(&String.to_integer/1)

    if Enum.empty?(all_seq), do: 0, else: Enum.max(all_seq)
  end


  def fetch(_dir, source, event_id) do
    if event = Repo.get_by(Event, source: source, id: event_id) do
      {:ok, Event.to_cloudevent(event)}
    else
      {:error, :not_found}
    end
  end

  def list_streams(root_dir) do
    case File.ls(streams_path(root_dir)) do
      {:ok, streams} -> streams
      {:error, :enoent} -> []
      err -> raise err
    end
  end

  @doc """
  Returns events from a stream.

  ## Options

  - `:direction` - when `:forward`, the first element in the returned list is the earliest event that occurred. When `:backward`, the first element is the latest. Default: `:forward`.
  - `:from_revision` - the revision to start the list from, as an integer. Can also be `:start`, which starts the list from the earliest revision, or `:end`, which starts the list at the latest. You must set this to `:end` when `:direction` is set to `:backwards`. Default: `:start`
  - `:limit` - the maximum number of events to return. Default: `1000`, and cannot be set higher.
  """
  def read(dir, stream_id, opts \\ []) do
    direction = Keyword.get(opts, :direction, :forward)
    from_revision = Keyword.get(opts, :from_revision, :start)
    limit = Keyword.get(opts, :limit, 1_000) |> min(1_000)

    revision_range =
      case {direction, from_revision} do
        {:forward, :end} -> []
        {:forward, :start} ->
          range_end = min(last_revision(dir, stream_id), limit)
          1..range_end
        {:forward, range_start} ->
          range_end = min(last_revision(dir, stream_id), range_start + limit)
          range_start..range_end
        {:backward, :start} -> []
        {:backward, :end} ->
          range_start = min(last_revision(dir, stream_id), limit)
          range_start..0
        {:backward, range_start} ->
          range_end = max(last_revision(dir, stream_id), range_start - limit)
          range_start..range_end
      end
      |> Enum.map(&Integer.to_string/1)

    Repo.all(from e in Event, where: e.source == ^stream_id, where: e.extensions["sequence"] in ^revision_range, order_by: e.extensions["sequence"])
    |> Enum.map(&Event.to_cloudevent/1)
  end

  def stat(dir, source, id) do
    event_path(dir, source, id)
    |> File.stat()
  end

  @doc """
  Returns the root of the global path for events.

  ## Examples

      iex> Loom.Store.events_path("/apps/loom")
      "/apps/loom/events"
  """
  @spec events_path(Path.t()) :: Path.t()
  def events_path(root_dir) do
    Path.join([root_dir, "events"])
  end

  @doc """
  Returns the root of the path for events published by a single event source.

  ## Examples

      iex> Loom.Store.event_source_path("/apps/loom", "myapp")
      "/apps/loom/events/myapp"
  """
  @spec event_source_path(Path.t(), event_source) :: Path.t()
  def event_source_path(root_dir, event_source) do
    events_path(root_dir)
    |> Path.join(Zarex.sanitize(event_source))
  end

  @doc """
  Returns the path that an event with the given source and ID is written to.

  ## Examples

      iex> Loom.Store.event_path("/apps/loom", "myapp", "000001")
      "/apps/loom/events/myapp/000001.json"
  """
  @spec event_path(Path.t(), event_source, event_id) :: Path.t()
  def event_path(root_dir, event_source, event_id) do
    event_source_path(root_dir, event_source)
    |> Path.join(Zarex.sanitize(event_id, padding: 5) <> ".json")
  end

  @doc """
  Returns the path for an event at the given stream ID and revision number.

  This reads the revision link from the filesystem and will raise if the revision does not exist.
  """
  @spec event_path_for_revision(Path.t(), stream_id(), revision()) :: Path.t()
  def event_path_for_revision(root_dir, stream_id, revision) do
    stream_revision_path(root_dir, stream_id, revision)
    |> File.read_link!()
  end

  @doc """
  Returns the path containing all stream directories.

  ## Examples

      iex> Loom.Store.streams_path("/apps/loom")
      "/apps/loom/streams"
  """
  @spec streams_path(Path.t()) :: Path.t()
  def streams_path(root_dir) do
    Path.join(root_dir, "streams")
  end

  @doc """
  Returns the path containing all revisions for a specific stream.

  ## Examples

      iex> Loom.Store.stream_path("/apps/loom", "abc123")
      "/apps/loom/streams/abc123"
  """
  @spec stream_path(Path.t(), stream_id()) :: Path.t()
  def stream_path(root_dir, stream_id) do
    streams_path(root_dir)
    |> Path.join(Zarex.sanitize(stream_id))
  end

  @doc """
  Returns the path for a specific event in a given stream.

  ## Examples

      iex> Loom.Store.stream_revision_path("/apps/loom", "abc123", 420)
      "/apps/loom/streams/abc123/420.json"
  """
  @spec stream_revision_path(Path.t(), stream_id(), revision()) :: Path.t()
  def stream_revision_path(root_dir, stream_id, revision) do
    stream_path(root_dir, stream_id)
    |> Path.join(Integer.to_string(revision) <> ".json")
  end
end
