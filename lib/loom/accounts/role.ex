defmodule Loom.Accounts.Role do
  use Loom.Schema
  import Ecto.Changeset

  alias Loom.Accounts.Team
  alias Loom.Accounts.User

  @primary_key false

  schema "roles" do
    belongs_to :team, Team, primary_key: true
    belongs_to :user, User, primary_key: true
    field :role, Ecto.Enum, values: [:member, :owner]

    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end
end
