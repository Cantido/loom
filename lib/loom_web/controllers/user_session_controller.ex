defmodule LoomWeb.UserSessionController do
  use LoomWeb, :controller

  alias Loom.Accounts
  alias LoomWeb.UserAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:danger, "Invalid email or password")
      |> render("new.html")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:success, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
