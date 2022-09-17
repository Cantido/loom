defmodule Loom.Accounts.Account do
  use Loom.Schema

  alias Loom.Source

  schema "accounts" do
    has_many :sources, Source
  end
end
