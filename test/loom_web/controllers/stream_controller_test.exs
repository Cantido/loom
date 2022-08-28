defmodule LoomWeb.StreamControllerTest do
  use LoomWeb.ConnCase

  setup do
    File.rm_rf("tmp")
    Loom.Cache.delete_all()
    Loom.Store.init("tmp")

    on_exit fn ->
      File.rm_rf("tmp")
    end

    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all streams", %{conn: conn} do
      conn = get(conn, Routes.stream_path(conn, :index))
      assert json_response(conn, 200)["data"] == ["$all"]
    end
  end

  describe "show" do
    test "returns all events in a stream", %{conn: conn} do
      event1 = Cloudevents.from_map!(%{id: "uuid-1", source: "store-show-test", type: "com.example.event", specversion: "1.0"})
      event2 = Cloudevents.from_map!(%{id: "uuid-2", source: "store-show-test", type: "com.example.event", specversion: "1.0"})

      {:ok, 1} = Loom.Store.append("tmp", "my-stream", event1)
      {:ok, 2} = Loom.Store.append("tmp", "my-stream", event2)

      conn = get(conn, Routes.stream_path(conn, :show, "my-stream"))

      assert [actual_event1, actual_event2] = json_response(conn, 200)
    end
  end
end
