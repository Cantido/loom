defmodule Loom.Event do
  use Ecto.Schema

  @primary_key {:id, :binary_id, [autogenerate: true]}
  schema "loom_events" do
    field :type, :string
    field :stream_id, :string
    field :revision, :integer
  end
end
