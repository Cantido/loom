defmodule Loom.Schema do
  @moduledoc """
  Defines `Ecto.Schema` module defaults.
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end
end
