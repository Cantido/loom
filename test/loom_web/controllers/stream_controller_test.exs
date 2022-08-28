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
end
