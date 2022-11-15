defmodule Loom do
  @moduledoc """
  Loom is an event store database.

  All events are represented by `Cloudevents` structs.

  ## Writing and reading events

  Write a new event to the store with the `append/4` function.
  This will return an `:ok` tuple with the revision number of that event.
  You can then read the event stream with `read/3`, which returns a `Stream` containing the requested events.

      iex> team = team_fixture()
      iex> source = source_fixture(%{team: team, source: "loom-doctest"})
      iex> {:ok, event} = Cloudevents.from_map(%{type: "com.example.event", specversion: "1.0", source: "loom-doctest", id: "a-uuid"})
      iex> Loom.append(event, team)
      {:ok, 1}
      iex> Loom.read("loom-doctest", team) |> Enum.at(0) |> Map.get(:id)
      "a-uuid"
  """

  use Boundary,
    deps: [],
    exports: [
      Accounts,
      Accounts.Team,
      Accounts.Token,
      Accounts.User,
      Adapters,
      Store,
      Store.Source,
      Subscriptions,
      Subscriptions.Webhook
    ]

  alias Loom.Repo

  @type stream_id :: String.t()
  @type event_id :: String.t()
  @type event_source :: String.t()
  @type revision :: non_neg_integer()

  @doc """
  Append an event to an event stream.
  """
  @spec append(Cloudevents.t(), Keyword.t()) ::
          {:ok, revision}
          | {:error, :event_exists}
          | {:error, :revision_mismatch}
  def append(event, team, opts \\ []) do
    team = Repo.preload(team, :sources)
    if Enum.any?(team.sources, fn src -> src.source == event["source"] end) do
      Loom.Store.append(event, opts)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Same as `append/4`, but raises on error.
  """
  def append!(event, team, opts \\ []) do
    case append(event, team, opts) do
      {:ok, new_store} -> new_store
      {:error, err} -> raise err
    end
  end

  def fetch(source, event_id, team) do
    team = Repo.preload(team, :sources)
    if Enum.any?(team.sources, fn src -> src.source == source end) do
      Loom.Store.fetch(source, event_id)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Returns the most recent sequence number from a source.
  """
  def last_sequence(source, team) do
    team = Repo.preload(team, :sources)
    if Enum.any?(team.sources, fn src -> src.source == source end) do
      Loom.Store.last_revision(source)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Returns events from a stream.

  ## Options

  - `:direction` - when `:forward`, the first element in the returned list is the earliest event that occurred.
    When `:backward`, the first element is the latest. Default: `:forward`.
  - `:from_revision` - the revision to start the list from, as an integer.
    Can also be `:start`, which starts the list from the earliest revision, or `:end`, which starts the list at the latest.
    You must set this to `:end` when `:direction` is set to `:backwards`. Default: `:start`
  - `:limit` - the maximum number of events to return. Default: `1000`, and cannot be set higher.
  """
  def read(source, team, opts \\ []) do
    team = Repo.preload(team, :sources)
    if Enum.any?(team.sources, fn src -> src.source == source end) do
      Loom.Store.read(source, opts)
    else
      {:error, :unauthorized}
    end
  end
end
