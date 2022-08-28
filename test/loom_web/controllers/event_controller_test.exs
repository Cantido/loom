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
      conn = post(conn, Routes.stream_path(conn, :create, "ohayo"), event: @create_attrs)
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

    test "returns 404 when event does not exist", %{conn: conn} do
      conn = get(conn, Routes.event_path(conn, :show, "loom-web-show-event-test", "12345"))

      assert json_response(conn, 404)["errors"] == [%{"title" => "Not Found"}]
    end
  end
end
