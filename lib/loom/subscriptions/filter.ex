defmodule Loom.Subscriptions.Filter do
  @moduledoc """
  A single filter expression.

  Filters are encoded in JSON like this:

  ```json
  { "dialect URI-Reference" : { <dialect-specific-properties> } }
  ```

  Sometimes instead of an object value containing properties, there can be a list, like in the `any` dialect.

  ```json
  {
    "any": [
      { "exact": { "type": "com.github.push" } },
      { "exact": { "subject": "https://github.com/cloudevents/spec" } }
    ]
  }
  ```

  To handle that, this Ecto struct always has a list as the `:properties` value,
  which will just contain a single map for those dialects that use an object.

  See: https://github.com/cloudevents/spec/blob/main/subscriptions/spec.md#324-filters
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Loom.Subscriptions.Filter

  embedded_schema do
    field :dialect, :string
    field :properties, {:array, :map}
  end

  @doc """
  Takes a map from the canonical JSON representation of a filter, and returns an Ecto changeset.

  ## Examples

      iex> cs = Filter.from_map(%Filter{}, %{"exact" => %{"type" => "com.example.event"}})
      iex> cs.valid?
      true

      iex> cs = Filter.from_map(%Filter{}, %{"all" => [%{"prefix" => %{"type" => "com.example."}}, %{"exact" => %{"source" => "http://example.com/event-emitter"}}]})
      iex> cs.valid?
      true
  """
  def from_map(filter, map) do
    [{dialect, properties}] = Map.to_list(map)
    if is_list(properties) do
      subfilters = Enum.map(properties, &from_map(%__MODULE__{}, &1))
      changeset(filter, %{dialect: dialect, properties: subfilters})
    else
      changeset(filter, %{dialect: dialect, properties: [properties]})
    end
  end

  @doc false
  def changeset(%Filter{} = filter, attrs) do
    filter
    |> cast(attrs, [:dialect, :properties])
    |> validate_required([:dialect, :properties])
  end

  def matches_event?(%{dialect: "exact", properties: [props]}, event) do
    Enum.all?(props, fn {key, expected_value} ->
      atom_key = String.to_existing_atom(key)
      actual_value = Map.fetch!(event, atom_key)
      actual_value == expected_value
    end)
  end

  def matches_event?(%{dialect: "prefix", properties: [props]}, event) do
    Enum.all?(props, fn {key, prefix} ->
      atom_key = String.to_existing_atom(key)
      actual_value = Map.fetch!(event, atom_key)
      String.valid?(actual_value) and String.starts_with?(actual_value, prefix)
    end)
  end

  def matches_event?(%{dialect: "suffix", properties: [props]}, event) do
    Enum.all?(props, fn {key, prefix} ->
      atom_key = String.to_existing_atom(key)
      actual_value = Map.fetch!(event, atom_key)
      String.valid?(actual_value) and String.ends_with?(actual_value, prefix)
    end)
  end

  def matches_event?(%{dialect: "all", properties: subfilters}, event) do
    Enum.all?(subfilters, fn subfilter ->
      matches_event?(subfilter, event)
    end)
  end

  def matches_event?(%{dialect: "any", properties: subfilters}, event) do
    Enum.any?(subfilters, fn subfilter ->
      matches_event?(subfilter, event)
    end)
  end

  def matches_event?(%{dialect: "not", properties: [subfilter]}, event) do
    not matches_event?(subfilter, event)
  end

  def matches_event?(%{dialect: "sql", properties: _expression}, _event) do
    raise "Loom does not yet support CloudEvents SQL dialect expressions"
  end
end
