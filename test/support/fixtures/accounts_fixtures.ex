
defmodule Loom.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loom.Accounts` context.
  """

  @doc """
  Generate an account.
  """
  def account_fixture(params \\ %{}) do
    params =
      Enum.into(params, %{
        email: Faker.Internet.safe_email()
      })

    {:ok, account} = Loom.Accounts.create_account(params)
    account
  end

  def token_fixture(params \\ %{}) do
    account = Map.get(params, :account, account_fixture())
    credentials = Loom.Accounts.generate_credentials()
    {:ok, token} = Loom.Accounts.create_token(account, credentials)
    %{token | password: credentials.password}
  end

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Loom.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  @doc """
  Generate a team.
  """
  def team_fixture(attrs \\ %{}) do
    {:ok, team} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> Loom.Accounts.create_team()

    team
  end
end
