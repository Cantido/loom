defmodule StoreBench do
  use Benchfella

  setup_all do
    Application.ensure_all_started(:loom)
    root_dir = Path.join([System.tmp_dir!(), "store-bench", Integer.to_string(System.monotonic_time())])
    File.mkdir_p!(root_dir)
    Loom.Store.init(root_dir)
    {:ok, root_dir}
  end

  teardown_all root_dir do
    File.rm_rf!(root_dir)
  end

  bench "write event", [event: random_event(), stream: random_stream(), revision: random_revision()] do
    _ = Loom.Store.append(bench_context, stream, event, expected_revision: revision)
    :ok
  end

  bench "read event (cache hit)", [params: random_cached(bench_context)] do
    {dir, stream_id} = params
    _ = Loom.Store.read(dir, stream_id)
    :ok
  end

  bench "read event (cache miss)", [params: random_uncached(bench_context)] do
    {dir, stream_id} = params
    _ = Loom.Store.read(dir, stream_id)
    :ok
  end

  defp random_uncached(root_dir) do
    event = random_event()

    Loom.Store.append(root_dir, "stream-1", event)
    path = Loom.Store.event_path(root_dir, event.source, event.id)
    Loom.Cache.delete(path)

    {root_dir, "stream-1"}
  end

  defp random_cached(root_dir) do
    event = random_event()

    Loom.Store.append(root_dir, "stream-1", event)

    {root_dir, "stream-1"}
  end

  defp random_event do
    id =
      case Enum.random([:uuid, :integer]) do
        :uuid -> Uniq.UUID.uuid7()
        :integer -> Integer.to_string(:rand.uniform(100)) # itentionally small to cause the occasional collision
      end
    source = Enum.random([
      "https://github.com/Cantido/loom",
      "urn:uuid:6e8bc430-9c3a-11d9-9669-0800200c9a66",
      "/sensors/tn-1234567/alerts",
      "1-555-123-4567"
    ])

    type = "io.github.cantido.loom.event-" <> Enum.random(~w(a b c d e f g))

    data_size = Enum.random(10..4_000)
    data = :rand.bytes(data_size) |> Base.encode64()

    Cloudevents.from_map!(%{
      id: id,
      source: source,
      type: type,
      data: data,
      specversion: "1.0"
    })
  end

  defp random_stream do
    case Enum.random([:random, :constant]) do
      :random -> Uniq.UUID.uuid7()
      :constant -> "my-stream"
    end
  end

  defp random_revision do
    Enum.random([
      :rand.uniform(10),
      :rand.uniform(10_000),
      :any,
      :no_stream,
      :stream_exists
    ])
  end
end
