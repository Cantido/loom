defmodule Loom.Accounts.Account do
  use Loom.Schema

  alias Loom.Accounts.User
  alias Loom.Store.Source
  alias Loom.Subscriptions.Webhook

  import Ecto.Changeset

  schema "accounts" do
    has_many :sources, Source
    has_many :webhooks, Webhook
    many_to_many :users, User, join_through: "users_accounts"
    field :email, :string
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
  end
end
