defmodule Loom.Accounts.Team do
  use Loom.Schema
  import Ecto.Changeset

  alias Loom.Accounts.Role

  schema "teams" do
    field :name, :string

    has_many :roles, Role
    has_many :users, through: [:roles, :user]

    timestamps()
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
