defmodule Loom.Store do
  @moduledoc """
  Loom's event store.
  """
  alias Loom.Event
  alias Loom.Repo

  import Ecto.Query

  require Logger

  def append(event, opts \\ []) do
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.one(:last_counter, from(c in Loom.Counter, where: c.source == ^event.source))
      |> Ecto.Multi.run(:current_counter, fn repo, %{last_counter: counter} ->
        counter = if is_nil(counter), do: %Loom.Counter{source: event.source}, else: counter

        if revision_match?(counter.value, Keyword.get(opts, :expected_revision, :any)) do
          cs = Ecto.Changeset.change(counter, %{value: counter.value + 1})
          repo.insert_or_update(cs)
        else
          {:error, :revision_mismatch}
        end
      end)
      |> Ecto.Multi.insert(:event, fn %{current_counter: current_counter} ->
        extensions =
          Map.put(event.extensions, "sequence", Integer.to_string(current_counter.value))

        event = %{event | extensions: extensions}
        event = if is_nil(event.time), do: %{event | time: DateTime.utc_now()}, else: event

        Loom.Event.from_cloudevent(event)
      end)
      |> Ecto.Multi.run(:webhook, fn _, %{event: event} ->
        event = Event.to_cloudevent(event)
        Loom.Subscriptions.send_webhooks(event)
        LoomWeb.Endpoint.broadcast!("stream:" <> event.source, "event", event)
        {:ok, nil}
      end)
      |> Repo.transaction()

    case result do
      {:ok, results} ->
        {:ok, String.to_integer(results[:event].extensions["sequence"])}

      {:error, :current_counter, :revision_mismatch, _changes} ->
        {:error, :revision_mismatch}

      {:error, :event, _changeset, _changes} ->
        {:error, :event_exists}
    end
  end

  defp revision_match?(_, :any), do: true
  defp revision_match?(0, :no_stream), do: true
  defp revision_match?(_, :no_stream), do: false
  defp revision_match?(0, :stream_exists), do: false
  defp revision_match?(_, :stream_exists), do: true
  defp revision_match?(x, x), do: true
  defp revision_match?(_, _), do: false

  def last_revision(source) do
    if counter = Repo.one(from(c in Loom.Counter, where: c.source == ^source)) do
      counter.value
    else
      0
    end
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
        where: e.source == ^stream_id,
        where: e.extensions["sequence"] in ^revision_range,
        order_by: [{^sort_dir, e.extensions["sequence"]}]
    )
    |> Enum.map(&Event.to_cloudevent/1)
  end
end
