defmodule Loom.Accounts.Team do
  use Loom.Schema
  import Ecto.Changeset

  alias Loom.Accounts.Role
  alias Loom.Accounts.Token
  alias Loom.Accounts.User
  alias Loom.Store.Source
  alias Loom.Subscriptions.Webhook

  schema "teams" do
    field :name, :string
    field :stripe_subscription_item_id, :string

    belongs_to :billing_user, User
    has_many :sources, Source
    has_many :roles, Role
    has_many :users, through: [:roles, :user]
    has_many :tokens, Token
    has_many :webhooks, Webhook

    timestamps()
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def get_role(%__MODULE__{} = team, %User{} = user) do
    Enum.find(team.roles, fn role ->
      role.user_id == user.id
    end)
  end
end
