defmodule Loom.Subscriptions.Webhook do
  use Loom.Schema
  import Ecto.Changeset

  schema "webhooks" do
    field :token, :string, redact: true
    field :type, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:url, :token, :type])
    |> validate_required([:url, :token, :type])
  end
end
