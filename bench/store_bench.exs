defmodule StoreBench do
  use Benchfella


  setup_all do
    {:ok, _} = Application.ensure_all_started(:loom)

    benchmark_id = Uniq.UUID.uuid7(:slug)

    {:ok, user} = Loom.Accounts.register_user(%{email: "#{benchmark_id}@example.com", password: "benchfella is nice"})
    {:ok, team} = Loom.Accounts.create_team(%{name: benchmark_id}, user)

    {:ok, %{user: user, team: team}}
  end

  before_each_bench context do
    {:ok, context}
  end

  bench "write event", [event: random_event(), stream: random_stream(), revision: random_revision()] do
    _ = Loom.append(event, bench_context[:team], expected_revision: revision)
    :ok
  end

  bench "read event", [stream: random_stream()] do
    _ = Loom.read(stream, bench_context[:team])
    :ok
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

    %{
      id: id,
      source: source,
      type: type,
      data: data,
      specversion: "1.0"
    }
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
