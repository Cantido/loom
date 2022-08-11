defmodule Loom.StoreTest do
  use ExUnit.Case, async: true
  doctest Loom.Store
  alias Loom.Store

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "events"))
    File.mkdir_p!(Path.join(tmp_dir, "streams"))
    File.mkdir_p!(Path.join([tmp_dir, "streams", "$all"]))

    :ok
  end

  describe "append/4 with no previous events" do
    @tag :tmp_dir
    test "creates a file in the events dir", %{tmp_dir: dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "first"})

      {:ok, 1} = Store.append(dir, "test-stream", event)

      expected_event_path = Path.join([dir, "events", "first.json"])

      assert File.exists?(expected_event_path)
    end

    @tag :tmp_dir
    test "creates a link in the stream dir", %{tmp_dir: dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "first"})

      {:ok, 1} = Store.append(dir, "test-stream", event)

      expected_link_path = Path.join([dir, "streams", "test-stream", "1.json"])

      assert File.exists?(expected_link_path)
      assert File.lstat!(expected_link_path).type == :symlink
    end

    @tag :tmp_dir
    test "creates a file in the $all dir", %{tmp_dir: dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "first"})

      {:ok, 1} = Store.append(dir, "test-stream", event)

      expected_link_path = Path.join([dir, "streams", "$all", "1.json"])

      assert File.exists?(expected_link_path)
      assert File.lstat!(expected_link_path).type == :symlink
    end
  end

  describe "append/4 when the stream has events in it" do
    setup %{tmp_dir: tmp_dir} do
      {:ok, first_event} = Cloudevents.from_map(%{type: "test.setup.event", specversion: "1.0", source: "loom", id: "first"})

      {:ok, 1} = Store.append(tmp_dir, "test-stream", first_event)

      :ok
    end

    @tag :tmp_dir
    test "expecting a matching numeric revision", %{tmp_dir: tmp_dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.setup.event", specversion: "1.0", source: "loom", id: "matching"})
      {:ok, 2} = Store.append(tmp_dir, "test-stream", event, expected_revision: 1)

      expected_link_path = Path.join([tmp_dir, "streams", "test-stream", "2.json"])

      assert File.exists?(expected_link_path)
      assert File.lstat!(expected_link_path).type == :symlink
    end

    @tag :tmp_dir
    test "expecting a mis-matching numeric revision", %{tmp_dir: tmp_dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.setup.event", specversion: "1.0", source: "loom", id: "mismatched"})
      {:error, :revision_mismatch} = Store.append(tmp_dir, "test-stream", event, expected_revision: 2)

      event_path = Path.join([tmp_dir, "events", "mismatched.json"])
      link_path = Path.join([tmp_dir, "streams", "test-stream", "2.json"])

      refute File.exists?(event_path)
      refute File.exists?(link_path)
    end

    @tag :tmp_dir
    test "appending an event that has already been inserted", %{tmp_dir: tmp_dir} do
      {:ok, event} = Cloudevents.from_map(%{type: "test.duplicate.event", specversion: "1.0", source: "loom", id: "first"})
      {:ok, 2} = Store.append(tmp_dir, "test-stream", event)

      assert File.ls!(Path.join(tmp_dir, "events")) == ["first.json"]
    end
  end

  describe "read" do
    @tag :tmp_dir
    test "forward from start", %{tmp_dir: tmp_dir} do
      {:ok, first_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "first"})
      {:ok, second_event} = Cloudevents.from_map(%{type: "test.event", specversion: "1.0", source: "loom", id: "second"})

      {:ok, 1} = Store.append(tmp_dir, "test-stream", first_event)
      {:ok, 2} = Store.append(tmp_dir, "test-stream", second_event)

      events = Store.read(tmp_dir, "test-stream", direction: :forward, from_revision: :start)

      assert Enum.to_list(events) == [first_event, second_event]
    end
  end
end
