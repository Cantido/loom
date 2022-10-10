defmodule LoomWeb.TokenController do
  use LoomWeb, :controller

  alias Loom.Accounts
  alias Loom.Accounts.Token

  def index(conn, _params) do
    tokens = Accounts.list_tokens(conn.assigns[:current_user])
    render(conn, "index.html", tokens: tokens)
  end

  def new(conn, _params) do
    changeset = Accounts.change_token(%Token{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"token" => token_params}) do
    case Accounts.create_token(token_params) do
      {:ok, token} ->
        conn
        |> put_flash(:info, "Token created successfully.")
        |> redirect(to: Routes.token_path(conn, :show, token))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    token = Accounts.get_token!(id)
    render(conn, "show.html", token: token)
  end

  def edit(conn, %{"id" => id}) do
    token = Accounts.get_token!(id)
    changeset = Accounts.change_token(token)
    render(conn, "edit.html", token: token, changeset: changeset)
  end

  def update(conn, %{"id" => id, "token" => token_params}) do
    token = Accounts.get_token!(id)

    case Accounts.update_token(token, token_params) do
      {:ok, token} ->
        conn
        |> put_flash(:info, "Token updated successfully.")
        |> redirect(to: Routes.token_path(conn, :show, token))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", token: token, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    token = Accounts.get_token!(id)
    {:ok, _token} = Accounts.delete_token(token)

    conn
    |> put_flash(:info, "Token deleted successfully.")
    |> redirect(to: Routes.token_path(conn, :index))
  end
end
