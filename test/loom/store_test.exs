defmodule Loom.StoreTest do
  use ExUnit.Case, async: true
  doctest Loom.Store
  alias Loom.Store

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "events"))
    File.mkdir_p!(Path.join(tmp_dir, "streams"))

    :ok
  end

  describe "append/4 with no previous events" do
    @tag :tmp_dir
    test "creates a file in the events dir", %{tmp_dir: dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "first"})

      {:ok, _} = Store.append("test-stream", event, root_dir: dir)

      expected_event_path = Path.join([dir, "events", "first.json"])

      assert File.exists?(expected_event_path)
    end
  end

  describe "append/4 when the stream has events in it" do
    setup %{tmp_dir: tmp_dir} do
      {:ok, first_event} = Cloudevents.from_map(%{type: "test.setup.event", specversion: "1.0", source: "loom", id: "first"})

      {:ok, _event} = Store.append("test-stream", first_event, root_dir: tmp_dir)

      :ok
    end

    @tag :tmp_dir
    test "expecting a matching numeric revision", %{tmp_dir: tmp_dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.setup.event", specversion: "1.0", source: "loom", id: "matching"})
      {:ok, _event} = Store.append("test-stream", event, expected_revision: 1, root_dir: tmp_dir)
    end

    @tag :tmp_dir
    test "expecting a mis-matching numeric revision", %{tmp_dir: tmp_dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.setup.event", specversion: "1.0", source: "loom", id: "mismatched"})
      {:error, :revision_mismatch} = Store.append("test-stream", event, expected_revision: 2, root_dir: tmp_dir)
    end

    @tag :tmp_dir
    test "appending an event that has already been inserted", %{tmp_dir: tmp_dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.duplicate.event", specversion: "1.0", source: "loom", id: "first"})
      {:ok, 2} = Store.append("test-stream", event, root_dir: tmp_dir)

      assert File.ls!(Path.join(tmp_dir, "events")) == ["first.json"]
    end
  end

  describe "read" do
    @tag :tmp_dir
    test "forward from start", %{tmp_dir: tmp_dir} do
      {:ok, first_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "first"})
      {:ok, second_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "second"})

      {:ok, _event} = Store.append("test-stream", first_event, root_dir: tmp_dir)
      {:ok, _event} = Store.append("test-stream", second_event, root_dir: tmp_dir)

      events = Store.read("test-stream", direction: :forward, from_revision: :start, root_dir: tmp_dir)

      assert Enum.to_list(events) == [first_event, second_event]
    end
  end
end
