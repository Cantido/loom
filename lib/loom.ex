defmodule Loom do
  @moduledoc """
  Loom is a filesystem-based event store.

  All Loom functions require a base directory argument.
  Inside that directory, events are created at `events/<event-id>.json`,
  and streams are created at `streams/<stream-id>/<revison-number>.json`.
  The files in each stream directory are symlinks to events in `events/`.

  Events are JSON-encoded according to the [CloudEvents spec](cloudevents.io).
  """
end
