defmodule Loom.Accounts.Team do
  use Loom.Schema
  import Ecto.Changeset

  alias Loom.Accounts.Role
  alias Loom.Accounts.Token

  schema "teams" do
    field :name, :string

    has_many :roles, Role
    has_many :users, through: [:roles, :user]
    has_many :tokens, Token

    timestamps()
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
