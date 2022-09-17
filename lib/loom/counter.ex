defmodule Loom.Counter do
  @moduledoc """
  The latest sequence number of events from a particular source.
  """

  use Loom.Schema
  alias Loom.Store.Source
  import Ecto.Changeset

  @primary_key false
  schema "counters" do
    belongs_to :source, Source, primary_key: true
    field :value, :integer, default: 0
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [])
    |> validate_required([])
  end
end
