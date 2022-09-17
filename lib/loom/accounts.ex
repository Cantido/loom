defmodule Loom.Accounts do
  alias Loom.Accounts.Account
  alias Loom.Accounts.Token
  alias Loom.Repo

  import Ecto.Query

  require Logger

  def create_account do
    Repo.insert(%Account{})
  end

  def generate_credentials do
    %{
      username: Uniq.UUID.uuid7(:slug),
      password: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    }
  end

  def create_token(account, params \\ %{}) do
    Token.changeset(%Token{}, params)
    |> Ecto.Changeset.put_assoc(:account, account)
    |> Repo.insert()
  end

  def verify_token(username, password) do
    Repo.one(from t in Token, where: [username: ^username], preload: [account: [sources: []]])
    |> Argon2.check_pass(password)
  end
end
