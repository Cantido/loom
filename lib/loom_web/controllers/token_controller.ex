defmodule LoomWeb.TokenController do
  use LoomWeb, :controller

  alias Loom.Accounts
  alias Loom.Accounts.Token

  def index(conn, %{"team_id" => team_id}) do
    team = Accounts.get_team!(team_id)
    render(conn, "index.html", team: team, tokens: team.tokens)
  end

  def new(conn, %{"team_id" => team_id}) do
    team = Accounts.get_team!(team_id)
    changeset = Accounts.change_token(%Token{})
    render(conn, "new.html", team: team, changeset: changeset)
  end

  def create(conn, %{"team_id" => team_id, "token" => token_params}) do
    team = Accounts.get_team!(team_id)
    case Accounts.create_token(team, token_params) do
      {:ok, token} ->
        conn
        |> put_flash(:info, "Token created successfully.")
        |> redirect(to: Routes.team_token_path(conn, :show, team, token))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", team: team, changeset: changeset)
    end
  end

  def show(conn, %{"team_id" => team_id, "id" => id}) do
    team = Accounts.get_team!(team_id)
    token = Accounts.get_token!(id)
    render(conn, "show.html", team: team, token: token)
  end

  def edit(conn, %{"team_id" => team_id, "id" => id}) do
    team = Accounts.get_team!(team_id)
    token = Accounts.get_token!(id)
    changeset = Accounts.change_token(token)
    render(conn, "edit.html", team: team, token: token, changeset: changeset)
  end

  def update(conn, %{"team_id" => team_id, "id" => id, "token" => token_params}) do
    team = Accounts.get_team!(team_id)
    token = Accounts.get_token!(id)

    case Accounts.update_token(token, token_params) do
      {:ok, token} ->
        conn
        |> put_flash(:info, "Token updated successfully.")
        |> redirect(to: Routes.team_token_path(conn, :show, team, token))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", team: team, token: token, changeset: changeset)
    end
  end

  def delete(conn, %{"team_id" => team_id, "id" => id}) do
    team = Accounts.get_team!(team_id)
    token = Accounts.get_token!(id)
    {:ok, _token} = Accounts.delete_token(token)

    conn
    |> put_flash(:info, "Token deleted successfully.")
    |> redirect(to: Routes.team_token_path(conn, :index, team))
  end
end
