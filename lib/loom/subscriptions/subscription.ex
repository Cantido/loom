defmodule Loom.Subscriptions.Subscription do
  use Loom.Schema
  import Ecto.Changeset
  alias Loom.Store.Source

  schema "subscriptions" do
    belongs_to :source, Source, on_replace: :update

    field :config, {:map, :string}
    field :filters, {:map, :string}
    field :protocol, :string
    field :protocolsettings, {:map, :string}
    field :sink, :string
    field :sink_credential, {:map, :string}
    field :types, {:array, :string}

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:types, :config, :filters, :sink, :sink_credential, :protocol, :protocolsettings])
    |> cast_assoc(:source)
    |> validate_required([:sink, :protocol])
  end
end
