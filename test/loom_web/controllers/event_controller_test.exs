defmodule LoomWeb.EventControllerTest do
  use LoomWeb.ConnCase

  @create_attrs %{
    id: "some id",
    source: "some source",
    type: "com.example.event",
    specversion: "1.0"
  }
  @update_attrs %{
    id: "some updated id"
  }
  @invalid_attrs %{id: nil}

  setup do
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
      assert %{"id" => "some id"} = json_response(conn, 201)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.event_path(conn, :create), event: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "show event" do
    test "renders an event", %{conn: conn} do
      event = Cloudevents.from_map!(%{specversion: "1.0", id: "12345", source: "loom-web-show-event-test", type: "com.example.event"})

      {:ok, revision} = Loom.Store.append("tmp", "test-stream", event)

      conn = get(conn, Routes.event_path(conn, :show, "12345"))

      assert json_response(conn, 200)["data"]["id"] == "12345"
    end
  end
end
