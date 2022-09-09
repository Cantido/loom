defmodule Loom.StoreTest do
  use Loom.DataCase, async: true
  alias Loom.Event
  alias Loom.Repo
  alias Loom.Store
  import Ecto.Query

  doctest Loom.Store

  setup context do
    if Map.has_key?(context, :tmp_dir) do
      tmp_dir = context.tmp_dir
      Loom.Store.init(tmp_dir)
    end

    :ok
  end

  describe "append/4 with no previous events" do
    test "creates a an event" do
      event_id = Uniq.UUID.uuid7()
      {:ok, event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: event_id})

      {:ok, 1} = Store.append(nil, "test-stream", event)

      assert Repo.exists?(from e in Event, where: e.id == ^event_id, where: e.source == "loom")
    end
  end

  describe "read" do
    @tag :tmp_dir
    test "forward from start", %{tmp_dir: tmp_dir} do
      {:ok, first_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "read-forward-test", id: "first-to-read"})
      {:ok, second_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "read-forward-test", id: "second-to-read"})

      {:ok, 1} = Store.append(tmp_dir, "read-forward-test", first_event)
      {:ok, 2} = Store.append(tmp_dir, "read-forward-test", second_event)

      events = Store.read(tmp_dir, "read-forward-test", direction: :forward, from_revision: :start)

      assert Enum.count(events) == 2
      assert Enum.at(events, 0).id == "first-to-read"
      assert Enum.at(events, 1).id == "second-to-read"
    end

    @tag :tmp_dir
    test "limit", %{tmp_dir: tmp_dir} do
      {:ok, first_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "read-limit-test", id: "before-limit"})
      {:ok, second_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "read-limit-test", id: "after-limit"})

      {:ok, 1} = Store.append(tmp_dir, "read-limit-test", first_event)
      {:ok, 2} = Store.append(tmp_dir, "read-limit-test", second_event)

      events = Store.read(tmp_dir, "read-limit-test", direction: :forward, from_revision: :start, limit: 1)

      assert Enum.count(events) == 1
      assert List.first(events)
    end
  end
end
