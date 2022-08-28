defmodule LoomWeb.EventControllerTest do
  use LoomWeb.ConnCase

  @create_attrs %{
    id: "some id",
    source: "some source",
    type: "com.example.event",
    specversion: "1.0"
  }
  @invalid_attrs %{id: nil}

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

  describe "create event" do
    test "renders event when data is valid", %{conn: conn} do
      conn = post(conn, Routes.event_path(conn, :create), event: @create_attrs, stream_id: "ohayo")
      assert %{"id" => "some id"} = json_response(conn, 201)
    end
  end

  describe "show event" do
    test "renders an event", %{conn: conn} do
      event = Cloudevents.from_map!(%{specversion: "1.0", id: "12345", source: "loom-web-show-event-test", type: "com.example.event"})

      {:ok, _revision} = Loom.Store.append("tmp", "test-stream", event)

      conn = get(conn, Routes.event_path(conn, :show, "loom-web-show-event-test", "12345"))

      assert json_response(conn, 200) == Cloudevents.to_json(event) |> Jason.decode!()
    end

    test "includes an etag header", %{conn: conn} do
      event = Cloudevents.from_map!(%{specversion: "1.0", id: "12345", source: "loom-web-show-event-test", type: "com.example.event"})

      {:ok, _revision} = Loom.Store.append("tmp", "test-stream", event)

      conn = get(conn, Routes.event_path(conn, :show, "loom-web-show-event-test", "12345"))

      assert [header] = get_resp_header(conn, "etag")
      assert String.starts_with?(header, ~s("))
      assert String.ends_with?(header, ~s("))
    end

    test "includes an last-modified header", %{conn: conn} do
      event = Cloudevents.from_map!(%{specversion: "1.0", id: "12345", source: "loom-web-show-event-test", type: "com.example.event"})

      {:ok, _revision} = Loom.Store.append("tmp", "test-stream", event)

      conn = get(conn, Routes.event_path(conn, :show, "loom-web-show-event-test", "12345"))

      assert [header] = get_resp_header(conn, "last-modified")
      last_modified = Timex.parse!(header, "{RFC1123}")
      assert Timex.before?(last_modified, Timex.now())
    end

    test "includes a cache-control header", %{conn: conn} do
      event = Cloudevents.from_map!(%{specversion: "1.0", id: "12345", source: "loom-web-show-event-test", type: "com.example.event"})

      {:ok, _revision} = Loom.Store.append("tmp", "test-stream", event)

      conn = get(conn, Routes.event_path(conn, :show, "loom-web-show-event-test", "12345"))

      assert [header] = get_resp_header(conn, "cache-control")
      assert header == "public, max-age=31536000, immutable"
    end

    test "returns 404 when event does not exist", %{conn: conn} do
      conn = get(conn, Routes.event_path(conn, :show, "loom-web-show-event-test", "12345"))

      assert json_response(conn, 404)["errors"] == [%{"title" => "Not Found"}]
    end
  end

  describe "show stream" do
    test "returns all events in a stream", %{conn: conn} do
      event1 = Cloudevents.from_map!(%{id: "uuid-1", source: "store-show-test", type: "com.example.event", specversion: "1.0"})
      event2 = Cloudevents.from_map!(%{id: "uuid-2", source: "store-show-test", type: "com.example.event", specversion: "1.0"})

      {:ok, 1} = Loom.Store.append("tmp", "my-stream", event1)
      {:ok, 2} = Loom.Store.append("tmp", "my-stream", event2)

      conn = get(conn, Routes.event_path(conn, :stream), stream_id: "my-stream")

      assert [actual_event1, actual_event2] = json_response(conn, 200)
    end
  end
end
