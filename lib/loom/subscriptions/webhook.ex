defmodule Loom.Subscriptions.Webhook do
  @moduledoc """
  The `Ecto` model for a Cloudevents webhook.
  """

  use Loom.Schema
  import Ecto.Changeset

  schema "webhooks" do
    field :token, :string, redact: true
    field :type, :string
    field :url, :string
    field :validated, :boolean, default: false
    field :allowed_rate, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:url, :token, :type, :validated, :allowed_rate])
    |> validate_required([:url, :token, :type])
  end
end
