defmodule Loom.Store do
  @moduledoc """
  Loom's event store.
  """
  alias Loom.Store.Event
  alias Loom.Repo
  alias Loom.Store.Source
  alias Loom.Store.Counter

  import Ecto.Query

  require OpenTelemetry.Tracer

  def append(event_params, opts \\ []) do
    with {:ok, cloudevent} <- Cloudevents.from_map(event_params) do
      set_otel_attributes(cloudevent)

      result =
        Loom.Cloudevents.put_new_time(cloudevent, DateTime.utc_now())
        |> set_traceparent()
        |> insert_event_multi(opts)
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
  end

  defp set_otel_attributes(cloudevent) do
    OpenTelemetry.Tracer.set_attribute("cloudevents.event_id", cloudevent.id)
    OpenTelemetry.Tracer.set_attribute("cloudevents.event_source", cloudevent.source)
    OpenTelemetry.Tracer.set_attribute("cloudevents.event_event_spec_version", cloudevent.specversion)
    OpenTelemetry.Tracer.set_attribute("cloudevents.event_type", cloudevent.type)
    OpenTelemetry.Tracer.set_attribute("cloudevents.event_subject", cloudevent.subject)
    :ok
  end

  defp set_traceparent(cloudevent) do
    context = Map.new(:otel_propagator_text_map.inject([]))

    if Map.has_key?(context, "traceparent") do
      Loom.Cloudevents.put_new_extension(cloudevent, "traceparent", context["traceparent"])
    else
      cloudevent
    end
  end

  defp insert_event_multi(cloudevent, opts) do
    Ecto.Multi.new()
    |> Ecto.Multi.one(
      :source,
      from(s in Source, where: s.source == ^cloudevent.source, preload: [:counter])
    )
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
      ce = Loom.Cloudevents.put_extension(cloudevent, "sequence", Integer.to_string(current_counter.value))


      {:ok, ce}
    end)
    |> Ecto.Multi.insert(:event, fn %{cloudevent: cloudevent, source: source} ->
      Ecto.build_assoc(source, :events)
      |> Loom.Store.Event.changeset(cloudevent)
    end)
    |> Ecto.Multi.run(:s3, fn _, %{cloudevent: cloudevent} ->
      event_json = Cloudevents.to_json(cloudevent)

      OpenTelemetry.Tracer.with_span "loom.s3:put_object" do
        ExAws.S3.put_object("events", event_key(cloudevent.source, cloudevent.id), event_json)
        |> ExAws.request()
      end
    end)
    |> Loom.Subscriptions.send_webhooks_multi()
  end

  defp revision_match?(_, :any), do: true
  defp revision_match?(0, :no_stream), do: true
  defp revision_match?(_, :no_stream), do: false
  defp revision_match?(0, :stream_exists), do: false
  defp revision_match?(_, :stream_exists), do: true
  defp revision_match?(x, x), do: true
  defp revision_match?(_, _), do: false

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
    req =
      OpenTelemetry.Tracer.with_span "loom.s3:get_object" do
        ExAws.S3.get_object("events", event_key(source, event_id))
      end

    case ExAws.request(req) do
      {:ok, resp} ->
        event = resp[:body]

        event =
          case Keyword.get(opts, :format, :json) do
            :json ->
              event

            :native ->
              Cloudevents.from_json!(event)
              |> Map.update!(:time, fn time ->
                {:ok, datetime, _} = DateTime.from_iso8601(time)
                datetime
              end)
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
      {:error, :not_found}
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

    stream =
      ExAws.S3.list_objects("events", prefix: source) |> ExAws.stream!() |> Stream.map(& &1.key)

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

  def read(stream_id, opts \\ []) do
    ids =
      Loom.Store.EventQueries.query_by_sequence(stream_id, opts)
      |> select([event], event.id)
      |> Repo.all()

    fetch_events(stream_id, ids)
  end

  def recent_events(source, opts \\ []) do
    ids =
      Loom.Store.EventQueries.query_by_time(source, opts)
      |> select([event], event.id)
      |> Repo.all()

    fetch_events(source, ids)
  end

  def fetch_events(source, ids) do
    events =
      Task.async_stream(ids, fn id ->
        fetch_event(source, id, format: :native)
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
