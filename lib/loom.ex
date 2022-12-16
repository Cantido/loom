defmodule Loom do
  @moduledoc """
  Loom is an event store database.

  All events are represented by `Cloudevents` structs.

  ## Writing and reading events

  Write a new event to the store with the `append/4` function.
  This will return an `:ok` tuple with the revision number of that event.
  You can then read the event stream with `read/3`, which returns a `Stream` containing the requested events.
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
      Store.Event,
      Subscriptions,
      Subscriptions.Subscription,
      Subscriptions.Webhook
    ]

  alias Loom.Repo
  alias Loom.Accounts.Team

  @type stream_id :: String.t()
  @type event_id :: String.t()
  @type event_source :: String.t()
  @type revision :: non_neg_integer()

  @append_options_schema NimbleOptions.new!([
    expected_revision: [
      type: {:or, [
        {:in, [:any, :no_stream, :stream_exists]},
        :non_neg_integer
      ]},
      default: :any,
      doc: """
      The expected state of the event stream.
      If `:any`, then the event will be appended to the stream regardless of the stream's state,
      If `:no_stream`, then the stream must not exist in order for the event to be appended.
      If `:stream_exists`, then there must be at least one event in the stream.
      If a positive integer, then there must be that many events in the stream.

      This is used for optimistic concurrency.
      The `append/3` function will return `{:error, :revision_mismatch}`
      if the provided option does not match the current state of the stream.
      """
    ],
    create_source: [
      type: :boolean,
      default: false
    ]
  ])

  @read_options_schema NimbleOptions.new!([
    direction: [
      type: {:in, [:forward, :backward]},
      default: :backward
    ],
    from_revision: [
      type: {:or, [
        {:in, [:start, :end]},
        :non_neg_integer
      ]},
      default: :start
    ],
    limit: [
      type: {:in, 0..1_000},
      default: 1_000
    ]
  ])

  @doc """
  Append an event to an event stream.
  """
  @spec append(Cloudevents.t(), Keyword.t()) ::
          {:ok, revision}
          | {:error, :event_exists}
          | {:error, :revision_mismatch}
  def append(event, %Team{} = team, opts \\ []) when is_map(event) and not is_struct(event) do
    opts = NimbleOptions.validate!(opts, @append_options_schema)

    team = Repo.preload(team, :sources)
    event_source = Map.get(event, :source, Map.get(event, "source"))

    if opts[:create_source] do
      {:ok, _source} = Loom.Store.create_source(team, event_source)
    end

    if opts[:create_source] or Enum.any?(team.sources, fn src -> src.source == event_source end) do
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
      Loom.Store.fetch_event(source, event_id, format: :native)
    else
      {:error, :unauthorized}
    end
  end

  def last_sequences(%Team{} = team) do
    team = Repo.preload(team, :sources)

    Enum.map(team.sources, &(&1.source))
    |> Loom.Store.last_revisions()
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
    opts = NimbleOptions.validate!(opts, @read_options_schema)

    team = Repo.preload(team, :sources)
    if Enum.any?(team.sources, fn src -> src.source == source end) do
      Loom.Store.read(source, opts)
    else
      {:error, :unauthorized}
    end
  end

  def delete_source(source, team) do
    team = Repo.preload(team, :sources)
    if Enum.any?(team.sources, fn src -> src.source == source end) do
      Loom.Store.delete_source(source)
    else
      {:error, :unauthorized}
    end
  end

  def delete_all_events(source, team) do
    team = Repo.preload(team, :sources)
    if Enum.any?(team.sources, fn src -> src.source == source end) do
      Loom.Store.delete_all_events(source)
    else
      {:error, :unauthorized}
    end
  end
end
