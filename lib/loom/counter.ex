defmodule Loom.Counter do
  @moduledoc """
  The latest sequence number of events from a particular source.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "counters" do
    field :source, :string, primary_key: true
    field :value, :integer, default: 0
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:source])
    |> validate_required([:source])
  end
end
