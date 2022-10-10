defmodule Loom.Accounts.Token do
  use Loom.Schema

  alias Loom.Accounts.Team

  import Ecto.Changeset

  schema "tokens" do
    belongs_to :team, Team
    field :username, :string
    field :password_hash, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:username, :password, :password_confirmation, :team_id])
    |> validate_confirmation(:password)
    |> validate_required([:username, :team_id])
    |> validate_length(:username, is: 22) # we're using UUID slugs which are 22 chars long
    |> put_pass_hash()
  end

  defp put_pass_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    change(changeset, Argon2.add_hash(password))
  end

  defp put_pass_hash(changeset), do: changeset
end
