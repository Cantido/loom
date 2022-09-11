defmodule LoomTest do
  use Loom.DataCase, async: true

  doctest Loom

  describe "append/4 with no previous events" do
    test "creates a an event" do
      {:ok, event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: "loom",
          id: "basic-create-event"
        })

      {:ok, 1} = Loom.append(event)

      {:ok, event} = Loom.fetch("loom", "basic-create-event")
    end
  end

  describe "read" do
    test "forward from start" do
      {:ok, first_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: "read-forward-test",
          id: "first-to-read"
        })

      {:ok, second_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: "read-forward-test",
          id: "second-to-read"
        })

      {:ok, 1} = Loom.append(first_event)
      {:ok, 2} = Loom.append(second_event)

      events = Loom.read("read-forward-test", direction: :forward, from_revision: :start)

      assert Enum.count(events) == 2
      assert Enum.at(events, 0).id == "first-to-read"
      assert Enum.at(events, 1).id == "second-to-read"
    end

    test "limit" do
      {:ok, first_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: "read-limit-test",
          id: "before-limit"
        })

      {:ok, second_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: "read-limit-test",
          id: "after-limit"
        })

      {:ok, 1} = Loom.append(first_event)
      {:ok, 2} = Loom.append(second_event)

      events = Loom.read("read-limit-test", direction: :forward, from_revision: :start, limit: 1)

      assert Enum.count(events) == 1
      assert List.first(events).id == "before-limit"
    end
  end
end
