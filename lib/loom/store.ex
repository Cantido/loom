defmodule Loom.Store do
  @moduledoc """
  Loom's event store.
  """
  alias Loom.Store.Event
  alias Loom.Repo
  alias Loom.Store.Source
  alias Loom.Store.Counter

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
      |> Ecto.Multi.run(:current_counter, fn repo, %{source: source} ->
        counter =
          if is_nil(source.counter) do
            Counter.changeset(%Counter{})
            |> Ecto.Changeset.put_assoc(:source, source)
          else
            Ecto.Changeset.change(source.counter)
          end

        counter_value = Ecto.Changeset.get_field(counter, :value)

        if revision_match?(counter_value, Keyword.get(opts, :expected_revision, :any)) do
          cs = Ecto.Changeset.change(counter, %{value: counter_value + 1})
          repo.insert_or_update(cs)
        else
          {:error, :revision_mismatch}
        end
      end)
      |> Ecto.Multi.run(:cloudevent, fn _, %{current_counter: current_counter} ->
        case Cloudevents.from_map(event_params) do
          {:ok, ce} ->
            ce = struct(ce, extensions: Map.put(ce.extensions, :sequence, Integer.to_string(current_counter.value)))

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

  defp revision_match?(_, :any), do: true
  defp revision_match?(0, :no_stream), do: true
  defp revision_match?(_, :no_stream), do: false
  defp revision_match?(0, :stream_exists), do: false
  defp revision_match?(_, :stream_exists), do: true
  defp revision_match?(x, x), do: true
  defp revision_match?(_, _), do: false

  def count_events(sources) when is_list(sources) do
    events_for_sources_query =
      from e in Event,
      join: s in assoc(e, :source),
      where: s.source in ^sources,
      group_by: s.source,
      select: {s.source, count()}

    Repo.all(events_for_sources_query) |> Map.new()
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
    counter =
      Repo.one(
        from c in Loom.Store.Counter,
        join: s in assoc(c, :source),
        where: s.source == ^source
      )

    if counter do
      counter.value
    else
      0
    end
  end

  def fetch_event(source, event_id, opts \\ []) do
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

  def list_streams do
    query = from e in Event, order_by: e.source, select: e.source
    Repo.all(query)
  end

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
          1..range_end

        {:forward, range_start} ->
          range_end = min(last_revision(stream_id), range_start + limit)
          range_start..range_end

        {:backward, :start} ->
          []

        {:backward, :end} ->
          range_start = min(last_revision(stream_id), limit)
          range_start..0

        {:backward, range_start} ->
          range_end = max(last_revision(stream_id), range_start - limit)
          range_start..range_end
      end
      |> Enum.map(&Integer.to_string/1)

    sort_dir =
      case direction do
        :forward -> :asc
        :backward -> :desc
      end

    events =
      Repo.all(
        from e in Event,
          join: s in assoc(e, :source),
          where: s.source == ^stream_id,
          where: e.extensions["sequence"] in ^revision_range,
          order_by: [{^sort_dir, e.extensions["sequence"]}],
          select: e.id
      )
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
