defmodule LoomWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use LoomWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import LoomWeb.ConnCase

      alias LoomWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint LoomWeb.Endpoint
    end
  end

  setup tags do
    Loom.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Loom.AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Loom.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  @doc """
  Sets up a team and source, and creates a Bearer token for them.
  """
  def log_in_api(%{conn: conn}) do
    source = Uniq.UUID.uuid7(:urn)

    team = Loom.AccountsFixtures.team_fixture()
    Loom.StoreFixtures.source_fixture(%{team: team, source: source})
    token = Loom.AccountsFixtures.token_fixture(%{team: team})

    {:ok, jwt, _claims} = LoomWeb.Tokens.encode_and_sign(token)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("authorization", "Bearer #{jwt}")

    %{
      conn: conn,
      team: team,
      source: source
    }
  end
end
