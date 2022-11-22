defmodule LoomWeb.StreamChannelTest do
  use LoomWeb.ChannelCase

  import Loom.AccountsFixtures
  import Loom.StoreFixtures

  setup do
    team = team_fixture()
    source = source_fixture(%{team: team, source: "stream-channel-test"})

    %{
      team: team,
      source: source
    }
  end

  setup do
    {:ok, _, socket} =
      LoomWeb.EventSocket
      |> socket()
      |> subscribe_and_join(LoomWeb.StreamChannel, "stream:stream-channel-test")

    %{socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "event", %{"some" => "data"})
    assert_push "event", %{"some" => "data"}
  end

  test "broadcasts are pushed to the client when an event is pushed" do
    event =
      %{
        specversion: "1.0",
        type: "com.example.event",
        id: "stream-channel-test-event",
        source: "stream-channel-test"
      }

    {:ok, _revision} = Loom.Store.append(event)

    assert_broadcast "event", %{id: "stream-channel-test-event"}
  end
end
