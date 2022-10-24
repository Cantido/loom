defmodule LoomWeb.TokenControllerTest do
  use LoomWeb.ConnCase

  import Loom.AccountsFixtures

  @create_attrs %{
    username: "AYO-aNOKdyag5_737Uluew",
    password: "Vie-H66IT3QFpBiFiTGuy5hAY4w4DnsAXW8nlgCEjbc"
  }
  @update_attrs %{
    username: "AYO-acofeFOrvShQ3LWZWg",
    password: "bRanj9OWVUgsIjXmOTrx8MF9ZjKWnUZ1DZQnwE60y7I"
  }
  @invalid_attrs %{
    username: "bad token!"
  }

  defp log_in(%{conn: conn}) do
    team = team_fixture() |> Loom.Repo.preload(:users)
    user = List.first(team.users)
    user_token = Loom.Accounts.generate_user_session_token(user)

    conn =
      conn
      |> init_test_session(%{user_token: user_token})

    %{
      conn: conn,
      user: user,
      team: team
    }
  end

  setup :log_in

  describe "index" do
    test "lists all tokens", %{conn: conn, team: team} do
      conn = get(conn, Routes.team_token_path(conn, :index, team.id))
      assert html_response(conn, 200) =~ "Listing Tokens"
    end
  end

  describe "new token" do
    test "renders form", %{conn: conn, team: team} do
      conn = get(conn, Routes.team_token_path(conn, :new, team.id))
      assert html_response(conn, 200) =~ "New Token"
    end
  end

  describe "create token" do
    test "redirects to show when data is valid", %{conn: conn, team: team} do
      conn = post(conn, Routes.team_token_path(conn, :create, team.id), token: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.team_token_path(conn, :show, team, id)

      conn = get(conn, Routes.team_token_path(conn, :show, team.id, id))
      assert html_response(conn, 200) =~ "Show Token"
    end

    test "renders errors when data is invalid", %{conn: conn, team: team} do
      conn = post(conn, Routes.team_token_path(conn, :create, team.id), token: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Token"
    end
  end

  describe "edit token" do
    setup [:create_token]

    test "renders form for editing chosen token", %{conn: conn, team: team, token: token} do
      conn = get(conn, Routes.team_token_path(conn, :edit, team.id, token))
      assert html_response(conn, 200) =~ "Edit Token"
    end
  end

  describe "update token" do
    setup [:create_token]

    test "redirects when data is valid", %{conn: conn, team: team, token: token} do
      conn = put(conn, Routes.team_token_path(conn, :update, team.id, token), token: @update_attrs)
      assert redirected_to(conn) == Routes.team_token_path(conn, :show, team.id, token)

      conn = get(conn, Routes.team_token_path(conn, :show, team.id, token))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, team: team, token: token} do
      conn = put(conn, Routes.team_token_path(conn, :update, team.id, token), token: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Token"
    end
  end

  describe "delete token" do
    setup [:create_token]

    test "deletes chosen token", %{conn: conn, team: team, token: token} do
      conn = delete(conn, Routes.team_token_path(conn, :delete, team.id, token))
      assert redirected_to(conn) == Routes.team_token_path(conn, :index, team.id)

      assert_error_sent 404, fn ->
        get(conn, Routes.team_token_path(conn, :show, team.id, token))
      end
    end
  end

  defp create_token(_) do
    token = token_fixture()
    %{token: token}
  end
end
