defmodule Loom.Store.Source do
  use Loom.Schema

  alias Loom.Accounts.Account
  alias Loom.Store.Counter

  import Ecto.Changeset

  schema "sources" do
    belongs_to :account, Account
    has_one :counter, Counter
    field :source, :string
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:source])
    |> validate_required([:source])
  end
end
