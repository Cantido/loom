defmodule Loom.Subscriptions.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Loom.Subscriptions.Filter

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "subscriptions" do
    field :config, :map, default: %{}
    embeds_many :filters, Filter, on_replace: :delete
    field :protocol, :string
    field :protocol_settings, {:map, :string}, default: %{}
    field :sink, :string
    field :sink_credentials, {:map, :string}, default: %{}
    field :source, :string
    field :types, {:array, :string}, default: []

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:source, :types, :sink, :sink_credentials, :protocol, :protocol_settings, :config])
    |> cast_embed(:filters, with: &Filter.from_map/2)
    |> validate_required([:sink, :protocol])
  end
end
