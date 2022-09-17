defmodule LoomWeb.StreamChannelTest do
  use LoomWeb.ChannelCase

  alias Loom.Accounts
  alias Loom.Store

  import Loom.AccountsFixtures
  import Loom.StoreFixtures

  setup do
    account = account_fixture()
    source = source_fixture(%{account: account, source: "stream-channel-test"})

    %{
      account: account,
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

  @tag :tmp_dir
  test "broadcasts are pushed to the client when an event is pushed", %{
    socket: socket,
    tmp_dir: tmp_dir
  } do
    event =
      Cloudevents.from_map!(%{
        specversion: "1.0",
        type: "com.example.event",
        id: "stream-channel-test-event",
        source: "stream-channel-test"
      })

    {:ok, _revision} = Loom.Store.append(event)

    assert_broadcast "event", %{id: "stream-channel-test-event"}
  end
end
