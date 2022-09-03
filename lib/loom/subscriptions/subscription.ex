defmodule Loom.Subscriptions.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Loom.Subscriptions.Filter

  schema "subscriptions" do
    field :config, {:map, :string}
    embeds_many :filters, Filter
    field :protocol, :string
    field :protocol_settings, {:map, :string}
    field :sink, :string
    field :sink_credentials, {:map, :string}
    field :source, :string
    field :types, {:array, :string}

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:source, :types, :sink, :sink_credentials, :protocol, :protocol_settings, :config])
    |> cast_embed(:filters)
    |> validate_required([:sink, :protocol])
  end
end
