defmodule LoomWeb.SubscriptionControllerTest do
  use LoomWeb.ConnCase

  import Loom.SubscriptionsFixtures
  import Loom.AccountsFixtures
  import Loom.StoreFixtures

  alias Loom.Subscriptions.Subscription

  @invalid_attrs %{config: nil, filters: nil, protocol: nil, protocolsettings: nil, sink: nil, sink_credential: nil, source: nil, types: nil}

  setup %{conn: conn} do
    team = team_fixture()
    source = source_fixture(%{team: team, source: Uniq.UUID.uuid7(:urn)})
    token = token_fixture(%{team: team})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", Plug.BasicAuth.encode_basic_auth(token.username, token.password))

    %{
      conn: conn,
      team: team,
      source: source
    }
  end

  describe "index" do
    test "lists all subscriptions", %{conn: conn} do
      conn = get(conn, Routes.subscription_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create subscription" do
    test "renders subscription when data is valid", %{conn: conn} do
      source = Uniq.UUID.uuid7(:urn)
      create_attrs = %{
        protocol: "HTTP",
        sink: "some sink",
        source: %{source: source, team: %{name: "some team"}},
        config: %{"config" => "a"},
        filters: %{},
        protocolsettings: %{"setting" => "a"},
        sink_credential: %{"cred" => "a"},
        types: ["com.example.type.a"]
      }

      conn = post(conn, Routes.subscription_path(conn, :create), subscription: create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.subscription_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "config" => %{"config" => "a"},
               "filters" => %{},
               "protocol" => "HTTP",
               "protocolsettings" => %{"setting" => "a"},
               "sink" => "some sink",
               "sink_credential" => %{"cred" => "a"},
               "source" => ^source,
               "types" => ["com.example.type.a"]
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.subscription_path(conn, :create), subscription: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update subscription" do
    setup [:create_subscription]

    test "renders subscription when data is valid", %{conn: conn, subscription: %Subscription{id: id} = subscription} do
      source = Uniq.UUID.uuid7(:urn)
      update_attrs = %{
        protocol: "HTTP",
        sink: "some updated sink",
        source: %{source: source, team: %{name: "some team"}},
        config: %{"config" => "b"},
        filters: %{},
        protocolsettings: %{"setting" => "b"},
        sink_credential: %{"cred" => "b"},
        types: ["com.example.type.b"]
      }
      conn = put(conn, Routes.subscription_path(conn, :update, subscription), subscription: update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.subscription_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "config" => %{"config" => "b"},
               "filters" => %{},
               "protocol" => "HTTP",
               "protocolsettings" => %{"setting" => "b"},
               "sink" => "some updated sink",
               "sink_credential" => %{"cred" => "b"},
               "source" => ^source,
               "types" => ["com.example.type.b"]
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, subscription: subscription} do
      conn = put(conn, Routes.subscription_path(conn, :update, subscription), subscription: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete subscription" do
    setup [:create_subscription]

    test "deletes chosen subscription", %{conn: conn, subscription: subscription} do
      conn = delete(conn, Routes.subscription_path(conn, :delete, subscription))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.subscription_path(conn, :show, subscription))
      end
    end
  end

  defp create_subscription(_) do
    subscription = subscription_fixture()
    %{subscription: subscription}
  end
end
