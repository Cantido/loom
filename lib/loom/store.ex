defmodule Loom.Store do
  @moduledoc """
  Loom's event store.

  Events belong to streams, which are lists of events.
  """

  @doc """
  Append an event to an event stream.

  ## Options

  - `:expected_revision` - The current revision of the stream you expect.
  This function will return `{:error, :revision_mismatch}` if the stream's current revision does not match.
  Can be an integer, or `:no_stream`, which asserts that the stream does not exist, or `:stream_exists`, which asserts that a stream with events already exists.
  """
  def append(stream_id, event, opts \\ []) do
    dir = Keyword.fetch!(opts, :root_dir)

    current_revision = last_revision(stream_id, root_dir: dir)
    expected_revision = Keyword.get(opts, :expected_revision, current_revision)

    if revision_match?(current_revision, expected_revision) do
      next_revision = current_revision + 1

      if next_revision == 1 do
        File.mkdir_p!(Path.join([dir, "streams", stream_id]))
      end

      event_path = Path.join([dir, "events", event.id <> ".json"])

      link_path =
        Path.join([dir, "streams", stream_id, Integer.to_string(next_revision) <> ".json"])

      case File.ln_s(event_path, link_path) do
        :ok ->
          case File.write(event_path, Cloudevents.to_json(event), [:exclusive]) do
            :ok ->
              {:ok, _all_revision} = retry_all_link(event_path, dir)
              {:ok, next_revision}

            {:error, :eexist} ->
              {:ok, next_revision}

            err ->
              err
          end

        {:error, :eexist} ->
          if revision_match?(next_revision, expected_revision) do
            append(stream_id, event, opts)
          else
            {:error, :revision_mismatch}
          end

        err ->
          err
      end
    else
      {:error, :revision_mismatch}
    end
  end

  defp retry_all_link(event_path, root_dir) do
    current_revision = last_revision("$all", root_dir: root_dir)
    do_retry_all_link(event_path, root_dir, current_revision, 0, 10)
  end

  defp do_retry_all_link(event_path, root_dir, current_revision, attempt_count, max_attempts) do
    if attempt_count >= max_attempts do
      raise "Attempted #{max_attempts} times to create a link in $all but they all failed."
    end

    next_revision = current_revision + 1
    link_path =
      Path.join([root_dir, "streams", "$all", Integer.to_string(next_revision) <> ".json"])

    case File.ln_s(event_path, link_path) do
      :ok ->
        {:ok, next_revision}
      {:error, :eexist} ->
        do_retry_all_link(event_path, root_dir, next_revision, attempt_count + 1, max_attempts)
      err ->
        err
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
  """
  def last_revision(stream_id, opts \\ []) do
    dir = Keyword.fetch!(opts, :root_dir)

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
  def read(stream_id, opts \\ []) do
    dir = Keyword.fetch!(opts, :root_dir)
    direction = Keyword.get(opts, :direction, :forward)
    from_revision = Keyword.get(opts, :from_revision, :start)

    stream_dir = Path.join([dir, "streams", stream_id])

    File.ls!(stream_dir)
    |> sort_filter(direction, from_revision)
    |> Task.async_stream(fn revision ->
      Path.join(stream_dir, revision)
      |> File.read_link!()
      |> File.read!()
    end)
    |> Stream.map(fn {:ok, event} -> Cloudevents.from_json!(event) end)
  end

  defp sort_filter(_events, :forward, :end), do: []
  defp sort_filter(_events, :backward, :start), do: []

  defp sort_filter(events, :forward, :start) do
    Enum.sort_by(events, &revision_from_filename/1)
  end

  defp sort_filter(events, :backward, :end) do
    Enum.sort_by(events, &revision_from_filename/1, :desc)
  end

  defp sort_filter(events, :forward, n) do
    Enum.sort_by(events, &revision_from_filename/1)
    |> Enum.drop(n)
  end

  defp sort_filter(events, :backward, n) do
    Enum.sort_by(events, &revision_from_filename/1, :desc)
    |> Enum.drop(n)
  end

  defp revision_from_filename(filename) do
    Path.rootname(filename, ".json")
    |> Path.basename()
    |> String.to_integer()
  end
end
