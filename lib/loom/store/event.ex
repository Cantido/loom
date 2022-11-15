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
    field :data, :binary
    field :datacontenttype, :string
    field :dataschema, :string
    field :time, :utc_datetime_usec
    field :extensions, :map
  end

  def from_cloudevent(ce) do
    params = Map.from_struct(ce)
    changeset(%__MODULE__{}, params)
  end

  @doc """
  Converts an Ecto struct to a `Cloudevents` struct.

  ## Examples

      iex> event = %Loom.Store.Event{id: "123", source: %Loom.Store.Source{source: "loom"}, type: "com.example.event", extensions: %{"sequence" => 1}}
      iex> Loom.Store.Event.to_cloudevent(event)
      %Cloudevents.Format.V_1_0.Event{id: "123", source: "loom", type: "com.example.event", extensions: %{"sequence" => 1}}
  """
  def to_cloudevent(%__MODULE__{} = event) do
    event
    |> Loom.Repo.preload(:source)
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Map.put(:specversion, "1.0")
    |> Map.update!(:source, fn s -> s.source end)
    |> Map.delete(:source_id)
    |> then(fn event ->
      if Map.get(event, :time) do
        Map.update!(event, :time, &DateTime.to_iso8601/1)
      else
        event
      end
    end)
    |> then(fn event ->
      Map.merge(event, event.extensions)
    end)
    |> Map.delete(:extensions)
    |> Cloudevents.from_map()
    |> then(fn {:ok, ce} -> ce end)
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [
      :id,
      :type,
      :data,
      :datacontenttype,
      :dataschema,
      :time,
      :extensions
    ])
    |> validate_required([:id, :type])
    |> validate_length(:data, max: 64 * 1024)
    |> validate_length(:id, min: 1)
    |> validate_length(:type, min: 1)
    |> validate_format(:datacontenttype, ~r(/))
    |> validate_length(:dataschema, min: 1)
    |> unique_constraint([:source_id, :id], error_key: :id)
  end
end
