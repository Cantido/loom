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
      iex> Loom.Store.append(root_dir, "my-stream-1", event)
      {:ok, 1}
      iex> Loom.Store.read(root_dir, "my-stream-1") |> Enum.at(0) |> Map.get(:id)
      "a-uuid"

  ## Filesystem structure

  Events are written as JSON blobs to the `events` directory, inside the given `root_dir`.
  A soft link is also created in the `streams` directory in `root_dir`, named after the current stream revision, and pointing to that event.
  There is also a special stream named `$all` that contains every event appended to the store.

  For example, the directory structure would look like this after calling `append/4` with five different events.

  ```
  /my/app/dir
  ├── events
  │   ├── my-source-1
  │   │   ├── 5add8700-5a01-46f3-a8c0-8315bb019909.json
  │   │   └── cd4ae630-f17b-480b-956b-c7c5d71a5590.json
  │   └── my-source-2
  │       ├── c0ca5952-a22a-41a6-b865-5ce692e6736e.json
  │       ├── 300d57fe-330b-45dc-aa81-90611cd0ae95.json
  │       └── 7e805bb4-f9b5-48ef-9b25-35ca1879552c.json
  └── streams
      ├── $all
      │   ├── 1.json
      │   ├── 2.json
      │   ├── 3.json
      │   ├── 4.json
      │   └── 5.json
      ├── my-stream-1
      │   ├── 1.json
      │   ├── 2.json
      │   └── 3.json
      ├── my-stream-2
      │   └── 1.json
      └── my-stream-3
          └── 1.json
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

  alias Loom.Cache

  @type stream_id :: String.t()
  @type event_id :: String.t()
  @type event_source :: String.t()
  @type revision :: non_neg_integer()

  def init(root_dir) do
    File.mkdir_p!(events_path(root_dir))
    File.mkdir_p!(stream_path(root_dir, "$all"))
  end

  @doc """
  Append an event to an event stream.

  ## Options

  - `:expected_revision` - The current revision of the stream you expect.
  This function will return `{:error, :revision_mismatch}` if the stream's current revision does not match.
  Can be an integer, or `:no_stream`, which asserts that the stream does not exist, or `:stream_exists`, which asserts that a stream with events already exists.
  """
  @spec append(Path.t(), stream_id(), Cloudevents.t(), Keyword.t()) :: {:ok, revision} | {:error, :revision_mismatch} | {:error, :retry_limit_reached}
  def append(dir, stream_id, event, opts \\ []) do
    current_revision = last_revision(dir, stream_id)
    expected_revision = Keyword.get(opts, :expected_revision, :any)

    if revision_match?(current_revision, expected_revision) do
      stream_directory = stream_path(dir, stream_id)
      unless File.exists?(stream_directory) do
        File.mkdir_p!(stream_directory)
      end

      source_directory = event_source_path(dir, event.source)
      unless File.exists?(source_directory) do
        File.mkdir_p!(source_directory)
      end

     event_path = event_path(dir, event.source, event.id)

      case retry_stream_link(dir, event_path, stream_id, &revision_match?(&1, expected_revision)) do
        {:ok, written_revision} ->
          case write_event(event_path, event) do
            :ok ->
              {:ok, _all_revision} = retry_stream_link(dir, event_path, "$all")
              {:ok, written_revision}

            err ->
              err
          end

        err ->
          err
      end
    else
      {:error, :revision_mismatch}
    end
  end

  defp write_event(event_path, event) do
    case File.write(event_path, Cloudevents.to_json(event), [:exclusive]) do
      :ok ->
        Cache.put(event_path, event)
        :ok
      {:error, :eexist} ->
        :ok
      err ->
        err
    end
  end

  defp retry_stream_link(root_dir, event_path, stream_id, revision_matcher \\ fn _ -> true end) do
    current_revision = last_revision(root_dir, stream_id)
    do_retry_stream_link(root_dir, event_path, stream_id, current_revision, revision_matcher, 0, 10)
  end

  defp do_retry_stream_link(root_dir, event_path, stream_id, current_revision, revision_matcher, attempt_count, max_attempts) do
    if attempt_count < max_attempts do

      if revision_matcher.(current_revision) do
        next_revision = current_revision + 1
        link_path = stream_revision_path(root_dir, stream_id, next_revision)

        case File.ln_s(event_path, link_path) do
          :ok ->
            {:ok, next_revision}
          {:error, :eexist} ->
            do_retry_stream_link(root_dir, event_path, stream_id, next_revision, revision_matcher, attempt_count + 1, max_attempts)
          err ->
            err
        end
      else
        {:error, :revision_mismatch}
      end
    else
      {:error, :retry_limit_reached}
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
  def last_revision(dir, stream_id, _opts \\ []) do
    stream_dir = Path.join([dir, "streams", stream_id])

    if File.exists?(stream_dir) do
      File.ls!(stream_dir)
      |> Enum.count()
    else
      0
    end
  end


  def fetch(dir, source, event_id) do
    path = event_path(dir, source, event_id)
    read_event(path)
  end

  @doc """
  Returns events from a stream.

  ## Options

  - `:direction` - when `:forward`, the first element in the returned list is the earliest event that occurred. When `:backward`, the first element is the latest. Default: `:forward`.
  - `:from_revision` - the revision to start the list from, as an integer. Can also be `:start`, which starts the list from the earliest revision, or `:end`, which starts the list at the latest. You must set this to `:end` when `:direction` is set to `:backwards`. Default: `:start`
  """
  def read(dir, stream_id, opts \\ []) do
    direction = Keyword.get(opts, :direction, :forward)
    from_revision = Keyword.get(opts, :from_revision, :start)

    revision_range =
      case {direction, from_revision} do
        {:forward, :end} -> []
        {:forward, :start} ->
          range_end = last_revision(dir, stream_id)
          1..range_end
        {:forward, range_start} ->
          range_end = last_revision(dir, stream_id)
          range_start..range_end
        {:backward, :start} -> []
        {:backward, :end} ->
          range_start = last_revision(dir, stream_id)
          range_start..0
        {:backward, range_start} ->
          range_end = last_revision(dir, stream_id)
          range_start..range_end
      end

    Task.async_stream(revision_range, fn revision ->
      event_path_for_revision(dir, stream_id, revision)
      |> read_event()
    end)
    |> Stream.map(fn {:ok, {:ok, event}} -> event end)
  end

  defp read_event(event_path) do
    if Cache.has_key?(event_path) do
      {:ok, Cache.get!(event_path)}
    else
      with {:ok, data} <- File.read(event_path),
           {:ok, json} <- Cloudevents.from_json(data) do
        {:ok, json}
      else
        err -> err
      end
    end
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
    |> Path.join(URI.encode_www_form(event_source))
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
    |> Path.join(URI.encode_www_form(event_id) <> ".json")
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
    |> Path.join(stream_id)
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
