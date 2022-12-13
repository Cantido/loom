defmodule Loom.Store do
  @moduledoc """
  Loom's event store.
  """
  alias Loom.Store.Event
  alias Loom.Repo
  alias Loom.Store.Source
  alias Loom.Store.Counter

  import Ecto.Query

  require Logger

  def append(event, opts \\ []) do
    source = Map.get(event, :source, Map.get(event, "source"))

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.one(:source, from(s in Source, where: s.source == ^source, preload: [:counter]))
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
      |> Ecto.Multi.insert(:event, fn %{current_counter: current_counter, source: source} ->

        extensions =
          event
          |> Map.drop(~w(id source type data datacontenttype dataschema time)a)
          |> Map.drop(~w(id source type data datacontenttype dataschema time))
          |> Map.reject(fn {_key, val} -> is_nil(val) end)
          |> Map.put("sequence", Integer.to_string(current_counter.value))

        Ecto.build_assoc(source, :events, time: DateTime.utc_now(), extensions: extensions)
        |> Loom.Store.Event.changeset(event)
      end)
      |> Loom.Subscriptions.send_webhooks_multi()
      |> Repo.transaction()

    case result do
      {:ok, results} ->
        {:ok, results[:event]}

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

  def fetch(source, event_id) do
    event =
      Repo.one(
        from e in Event,
        join: s in assoc(e, :source),
        where: s.source == ^source,
        where: e.id == ^event_id,
        preload: [:source]
      )
    if event do
      {:ok, event}
    else
      {:error, :not_found}
    end
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

  def fetch_source(source) do
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

    Repo.all(
      from e in Event,
        join: s in assoc(e, :source),
        where: s.source == ^stream_id,
        where: e.extensions["sequence"] in ^revision_range,
        order_by: [{^sort_dir, e.extensions["sequence"]}]
    )
  end
end
