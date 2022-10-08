defmodule LoomWeb.TeamController do
  use LoomWeb, :controller

  alias Loom.Accounts
  alias Loom.Accounts.Team

  def index(conn, _params) do
    teams = Accounts.list_teams(conn.assigns[:current_user])
    render(conn, "index.html", teams: teams)
  end

  def new(conn, _params) do
    changeset = Accounts.change_team(%Team{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"team" => team_params}) do
    case Accounts.create_team(team_params, conn.assigns[:current_user]) do
      {:ok, team} ->
        conn
        |> put_flash(:info, "Team created successfully.")
        |> redirect(to: Routes.team_path(conn, :show, team))
      {:error, :team, %Ecto.Changeset{} = changeset, _changes} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    team = Accounts.get_team!(id)
    render(conn, "show.html", team: team)
  end

  def edit(conn, %{"id" => id}) do
    team = Accounts.get_team!(id)
    changeset = Accounts.change_team(team)
    render(conn, "edit.html", team: team, changeset: changeset)
  end

  def update(conn, %{"id" => id, "team" => team_params}) do
    team = Accounts.get_team!(id)

    case Accounts.update_team(team, team_params) do
      {:ok, team} ->
        conn
        |> put_flash(:info, "Team updated successfully.")
        |> redirect(to: Routes.team_path(conn, :show, team))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", team: team, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    team = Accounts.get_team!(id)
    {:ok, _team} = Accounts.delete_team(team)

    conn
    |> put_flash(:info, "Team deleted successfully.")
    |> redirect(to: Routes.team_path(conn, :index))
  end
end
