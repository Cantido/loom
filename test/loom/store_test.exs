defmodule Loom.StoreTest do
  use ExUnit.Case
  doctest Loom.Store
  alias Loom.Store
  alias Loom.Event

  setup do
    Loom.ETS.delete_all(Event)
    :ok
  end

  describe "append/4 when the stream has events in it" do
    setup do
      first_event = %Event{type: "test.setup.event"}
      {:ok, _event} = Store.append("test-stream", first_event)

      :ok
    end

    test "expecting a matching numeric revision" do
      event = %Event{type: "test.event"}
      {:ok, _event} = Store.append("test-stream", event, expected_revision: 1)
    end

    test "expecting a mis-matching numeric revision" do
      event = %Event{type: "test.event"}
      {:error, :revision_mismatch} = Store.append("test-stream", event, expected_revision: 2)
    end
  end
end
