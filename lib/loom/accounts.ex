defmodule Loom.Accounts do
  alias Loom.Accounts.Account
  alias Loom.Accounts.Token
  alias Loom.Repo

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
    Repo.get_by(Token, username: username)
    |> Argon2.check_pass(password)
    |> tap(fn token -> Logger.info("token: #{inspect token, pretty: true}") end)
  end
end
