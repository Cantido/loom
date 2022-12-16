defmodule Loom.Store.Event do
  @moduledoc """
  Ecto schema for a CloudEvents event.
  """

  use Loom.Schema
  alias Loom.Store.Source
  import Ecto.Changeset

  @primary_key false
  schema "events" do
    belongs_to :source, Source, primary_key: true
    field :id, :string, primary_key: true
    field :type, :string
    field :datacontenttype, :string
    field :dataschema, :string
    field :time, :utc_datetime_usec
    field :subject, :string
    field :extensions, :map

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [
      :id,
      :type,
      :datacontenttype,
      :dataschema,
      :time,
      :subject,
      :extensions
    ])
    |> validate_required([:id, :type])
    |> validate_length(:id, min: 1)
    |> validate_length(:type, min: 1)
    |> validate_format(:datacontenttype, ~r(/))
    |> validate_length(:dataschema, min: 1)
    |> validate_length(:subject, min: 1)
    |> assoc_constraint(:source)
    |> unique_constraint([:source_id, :id], error_key: :id)
  end
end
