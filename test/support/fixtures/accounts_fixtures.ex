
defmodule Loom.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loom.Accounts` context.
  """

  @doc """
  Generate an account.
  """
  def account_fixture do
    {:ok, account} = Loom.Accounts.create_account()
    account
  end

  def token_fixture(params \\ %{}) do
    account = Map.get(params, :account, account_fixture())
    credentials = Loom.Accounts.generate_credentials()
    {:ok, token} = Loom.Accounts.create_token(account, credentials)
    %{token | password: credentials.password}
  end
end
