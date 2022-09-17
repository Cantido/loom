defmodule LoomTest do
  use Loom.DataCase, async: true

  doctest Loom

  import Loom.StoreFixtures

  @source "loom-test"

  setup do
    source = source_fixture(%{source: @source})
    %{source: source}
  end

  describe "append/4 with no previous events" do
    test "creates a an event" do
      {:ok, event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: @source,
          id: "basic-create-event"
        })

      {:ok, 1} = Loom.append(event)

      {:ok, event} = Loom.fetch(@source, "basic-create-event")
    end
  end

  describe "read" do
    test "forward from start" do
      {:ok, first_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: @source,
          id: "first-to-read"
        })

      {:ok, second_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: @source,
          id: "second-to-read"
        })

      {:ok, 1} = Loom.append(first_event)
      {:ok, 2} = Loom.append(second_event)

      events = Loom.read(@source, direction: :forward, from_revision: :start)

      assert Enum.count(events) == 2
      assert Enum.at(events, 0).id == "first-to-read"
      assert Enum.at(events, 1).id == "second-to-read"
    end

    test "limit" do
      {:ok, first_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: @source,
          id: "before-limit"
        })

      {:ok, second_event} =
        Cloudevents.from_map(%{
          type: "test.event",
          specversion: "1.0",
          source: @source,
          id: "after-limit"
        })

      {:ok, 1} = Loom.append(first_event)
      {:ok, 2} = Loom.append(second_event)

      events = Loom.read(@source, direction: :forward, from_revision: :start, limit: 1)

      assert Enum.count(events) == 1
      assert List.first(events).id == "before-limit"
    end
  end
end
