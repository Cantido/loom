defmodule LoomWeb.StreamControllerTest do
  use LoomWeb.ConnCase

  setup do
    root_dir = Application.fetch_env!(:loom, :root_dir)
    Loom.Store.delete_all(root_dir)
    Loom.Store.init(root_dir)
    on_exit fn ->
      Loom.Store.delete_all(root_dir)
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
