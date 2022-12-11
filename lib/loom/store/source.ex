defmodule Loom.Store.Source do
  use Loom.Schema

  alias Loom.Accounts.Team
  alias Loom.Store.Counter
  alias Loom.Subscriptions.Subscription

  import Ecto.Changeset

  schema "sources" do
    has_many :subscriptions, Subscription
    belongs_to :team, Team, on_replace: :update
    has_one :counter, Counter
    field :source, :string

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:source])
    |> cast_assoc(:team)
    |> validate_required([:source])
  end
end
