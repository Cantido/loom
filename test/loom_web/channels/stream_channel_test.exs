defmodule LoomWeb.StreamChannelTest do
  use LoomWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      LoomWeb.EventSocket
      |> socket()
      |> subscribe_and_join(LoomWeb.StreamChannel, "stream:test-stream")

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
  test "broadcasts are pushed to the client when an event is pushed", %{socket: socket, tmp_dir: tmp_dir} do
    event = Cloudevents.from_map!(%{
      specversion: "1.0",
      type: "com.example.event",
      id: "stream-channel-test-event",
      source: "stream-channel-test"
    })

    Loom.Store.init(tmp_dir)
    {:ok, _revision} = Loom.Store.append(tmp_dir, "test-stream", event)

    assert_broadcast "event", ^event
  end
end
