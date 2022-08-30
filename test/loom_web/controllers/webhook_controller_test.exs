defmodule LoomWeb.WebhookControllerTest do
  use LoomWeb.ConnCase

  import Loom.SubscriptionsFixtures

  alias Loom.Subscriptions.Webhook

  @create_attrs %{
    token: "some token",
    type: "some type",
    url: "some url",
    validated: true,
  }
  @update_attrs %{
    token: "some updated token",
    type: "some updated type",
    url: "some updated url"
  }
  @invalid_attrs %{token: nil, type: nil, url: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all webhooks", %{conn: conn} do
      conn = get(conn, Routes.webhook_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create webhook" do
    test "renders webhook when data is valid", %{conn: conn} do
      conn = post(conn, Routes.webhook_path(conn, :create), webhook: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.webhook_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "token" => "some token",
               "type" => "some type",
               "url" => "some url"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.webhook_path(conn, :create), webhook: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update webhook" do
    setup [:create_webhook]

    test "renders webhook when data is valid", %{conn: conn, webhook: %Webhook{id: id} = webhook} do
      conn = put(conn, Routes.webhook_path(conn, :update, webhook), webhook: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.webhook_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "token" => "some updated token",
               "type" => "some updated type",
               "url" => "some updated url"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, webhook: webhook} do
      conn = put(conn, Routes.webhook_path(conn, :update, webhook), webhook: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete webhook" do
    setup [:create_webhook]

    test "deletes chosen webhook", %{conn: conn, webhook: webhook} do
      conn = delete(conn, Routes.webhook_path(conn, :delete, webhook))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.webhook_path(conn, :show, webhook))
      end
    end
  end

  defp create_webhook(_) do
    webhook = webhook_fixture()
    %{webhook: webhook}
  end
end
