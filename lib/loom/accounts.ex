defmodule Loom.Accounts do
  alias Loom.Accounts.Account
  alias Loom.Source
  alias Loom.Repo

  import Ecto.Query

  def create_account do
    Repo.insert(%Account{})
  end
end
