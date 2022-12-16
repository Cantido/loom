defmodule Loom.Store do
  @moduledoc """
  Loom's event store.
  """
  alias Loom.Store.Event
  alias Loom.Repo
  alias Loom.Store.Source

  import Ecto.Query

  def append(event_params, opts \\ []) do
    source_param = Map.get(event_params, :source, Map.get(event_params, "source"))

    unless String.valid?(source_param) do
      raise ArgumentError, "Parameter :source must be a valid string"
    end

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.one(:source, from(s in Source, where: s.source == ^source_param, preload: [:counter]))
      |> Ecto.Multi.run(:check_source, fn _, %{source: source} ->
        if is_nil(source) do
          {:error, :source_not_found}
        else
          {:ok, true}
        end
      end)
      |> Ecto.Multi.run(:current_counter, fn _repo, %{source: source} ->
        expected_sequence = Keyword.get(opts, :expected_revision, :any)
        case Redix.command(:redix, ["FCALL", "revision_match_increment", "1", "loom:source:#{source.source}:last_sequence", expected_sequence]) do
          {:ok, "MISMATCH"} -> {:error, :revision_mismatch}
          {:ok, revision} -> {:ok, revision}
        end
      end)
      |> Ecto.Multi.run(:cloudevent, fn _, %{current_counter: current_counter} ->
        case Cloudevents.from_map(event_params) do
          {:ok, ce} ->
            ce = struct(ce, extensions: Map.put(ce.extensions, :sequence, Integer.to_string(current_counter)))

            ce =
              if is_nil(ce.time) do
                struct(ce, time: DateTime.utc_now())
              else
                ce
              end

            {:ok, ce}
          error ->
            error
        end
      end)
      |> Ecto.Multi.insert(:event, fn %{cloudevent: cloudevent, source: source} ->
        event_params =
          Cloudevents.to_map(cloudevent)
          |> Map.put(:extensions, cloudevent.extensions)

        Ecto.build_assoc(source, :events)
        |> Loom.Store.Event.changeset(event_params)
      end)
      |> Ecto.Multi.run(:s3, fn _, %{cloudevent: cloudevent} ->
        event_json = Cloudevents.to_json(cloudevent)

        ExAws.S3.put_object("events", event_key(cloudevent.source, cloudevent.id), event_json) |> ExAws.request()
      end)
      |> Ecto.Multi.run(:redis, fn _, %{current_counter: current_counter, cloudevent: cloudevent} ->
        Redix.command(:redix, ["HSET", "loom:source:#{cloudevent.source}:sequences", current_counter, cloudevent.id])
      end)
      |> Loom.Subscriptions.send_webhooks_multi()
      |> Repo.transaction()

    case result do
      {:ok, results} ->
        {:ok, results[:cloudevent]}

      {:error, :cloudevent, reason, _changes} ->
        {:error, reason}

      {:error, :check_source, :source_not_found, _changes} ->
        {:error, :source_not_found}

      {:error, :current_counter, :revision_mismatch, _changes} ->
        {:error, :revision_mismatch}

      {:error, :event, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def last_revisions(sources) do
    Repo.all(
      from s in Loom.Store.Source,
      left_join: c in assoc(s, :counter),
      where: s.source in ^sources,
      select: {s.source, coalesce(c.value, 0)}
    )
    |> Map.new()
  end

  def last_revision(source) do
    case Redix.command(:redix, ["GET", "loom:source:#{source}:last_sequence"]) do
      {:ok, nil} -> 0
      {:ok, sequence} -> String.to_integer(sequence)
    end
  end

  def fetch_event(source, event_id, opts \\ []) when is_binary(source) and is_binary(event_id) do
    req = ExAws.S3.get_object("events", event_key(source, event_id))

    case ExAws.request(req) do
      {:ok, resp} ->
        event = resp[:body]

        event =
          case Keyword.get(opts, :format, :json) do
            :json -> event
            :native -> Cloudevents.from_json!(event)
          end

        {:ok, event}
      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}
      error ->
        error
    end
  end

  def event_key(source, event_id) do
    source <> "/" <> event_id <> ".json"
  end

  def new_event_changeset(source) do
    Ecto.build_assoc(source, :events)
    |> Ecto.Changeset.change(%{
      id: Uniq.UUID.uuid4()
    })
  end

  def create_source(team, source_value) do
    Source.changeset(%Source{}, %{source: source_value})
    |> Ecto.Changeset.put_assoc(:team, team)
    |> Repo.insert()
  end

  def get_source!(source_id) do
    Repo.one!(from s in Source, where: [id: ^source_id], preload: [:team])
  end

  def fetch_source(source) when is_binary(source) do
    if source = Repo.one(from s in Source, where: s.source == ^source, preload: [:team]) do
      {:ok, source}
    else
      :error
    end
  end

  def delete_source(source) when is_binary(source) do
    Loom.Repo.delete_all(from s in Source, where: s.source == ^source)

    delete_all_events(source)

    :ok
  end

  def delete_all_events(source) when is_binary(source) do
    Loom.Repo.delete_all(
      from e in Event,
      join: s in assoc(e, :source),
      where: s.source == ^source
    )

    Redix.command!(:redix, ["DEL", "loom:source:#{source}:last_sequence"])
    Redix.command!(:redix, ["DEL", "loom:source:#{source}:sequences"])

    stream = ExAws.S3.list_objects("events", prefix: source) |> ExAws.stream!() |> Stream.map(& &1.key)
    req = ExAws.S3.delete_all_objects("events", stream)

    case ExAws.request(req) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  def list_streams do
    query = from e in Event, order_by: e.source, select: e.source
    Repo.all(query)
  end

  require Logger

  def read(stream_id, opts \\ []) do
    direction = Keyword.get(opts, :direction, :forward)
    from_revision = Keyword.get(opts, :from_revision, :start)
    limit = Keyword.get(opts, :limit, 1_000) |> min(1_000)

    revision_range =
      case {direction, from_revision} do
        {:forward, :end} ->
          []

        {:forward, :start} ->
          range_end = min(last_revision(stream_id), limit)
          if range_end < 1 do
            []
          else
            1..range_end
          end

        {:forward, range_start} ->
          range_end = min(last_revision(stream_id), range_start + limit - 1)
          if range_end < range_start do
            []
          else
            range_start..range_end
          end

        {:backward, :start} ->
          []

        {:backward, :end} ->
          range_start = min(last_revision(stream_id), limit)
          if range_start < 1 do
            []
          else
            range_start..1
          end

        {:backward, range_start} ->
          range_end = max(last_revision(stream_id), range_start - limit + 1)
          if range_start < range_end do
            []
          else
            range_start..range_end
          end
      end
      |> Enum.map(&Integer.to_string/1)

    if Enum.empty?(revision_range) do
      []
    else
      events =
        Redix.command!(:redix, ["HMGET", "loom:source:#{stream_id}:sequences"] ++ revision_range)
        |> tap(fn ids -> Logger.error("revision range: #{inspect revision_range} opts: #{inspect opts}, ids: #{inspect ids}") end)
        |> Task.async_stream(fn id ->
          fetch_event(stream_id, id, format: :native)
        end)
        |> Enum.map(fn {:ok, event} ->
          case event do
            {:ok, event} -> event
            error -> error
          end
        end)

      failures = Enum.filter(events, fn event -> match?({:error, _}, event) end)

      if Enum.any?(failures) do
        {:error, {:storage_failure, failures}}
      else
        events
      end
    end
  end
end
