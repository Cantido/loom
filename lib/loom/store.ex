defmodule Loom.Store do
  @moduledoc """
  Loom's event store.

  Events belong to streams, which are lists of events.
  """
  use Nebulex.Caching

  alias Loom.Cache

  @type stream_id :: String.t()
  @type event_id :: String.t()
  @type revision :: non_neg_integer()

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

      event_path = event_path(dir, event.id)

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
      event_path(dir, stream_id, revision)
      |> read_event()
    end)
    |> Stream.map(fn {:ok, event} -> event end)
  end

  @decorate cacheable(cache: Cache, key: event_path)
  defp read_event(event_path) do
    File.read!(event_path)
    |> Cloudevents.from_json!()
  end

  @spec events_path(Path.t()) :: Path.t()
  def events_path(root_dir) do
    Path.join([root_dir, "events"])
  end

  @spec event_path(Path.t(), event_id) :: Path.t()
  def event_path(root_dir, event_id) do
    events_path(root_dir)
    |> Path.join(event_id <> ".json")
  end

  @spec event_path(Path.t(), stream_id(), revision()) :: Path.t()
  def event_path(root_dir, stream_id, revision) do
    stream_revision_path(root_dir, stream_id, revision)
    |> File.read_link!()
  end

  @spec streams_path(Path.t()) :: Path.t()
  def streams_path(root_dir) do
    Path.join(root_dir, "streams")
  end

  @spec stream_path(Path.t(), stream_id()) :: Path.t()
  def stream_path(root_dir, stream_id) do
    streams_path(root_dir)
    |> Path.join(stream_id)
  end

  @spec stream_revision_path(Path.t(), stream_id(), revision()) :: Path.t()
  def stream_revision_path(root_dir, stream_id, revision) do
    stream_path(root_dir, stream_id)
    |> Path.join(Integer.to_string(revision) <> ".json")
  end
end
