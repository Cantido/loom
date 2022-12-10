defmodule LoomWeb.OauthController do
  use LoomWeb, :controller

  alias Loom.Accounts.Token

  def grant(conn, %{
        "grant_type" => "client_credentials",
        "client_id" => client_id,
        "client_secret" => client_secret
      }) do
    with {:ok, %Token{} = token} <- Loom.Accounts.verify_token(client_id, client_secret),
         {:ok, jwt, claims} <- LoomWeb.Tokens.encode_and_sign(token) do
      now_unix =
        DateTime.utc_now()
        |> DateTime.to_unix()

      expires_in = claims["exp"] - now_unix

      conn
      |> put_resp_header("cache-control", "no-store")
      |> json(%{
        access_token: jwt,
        token_type: "Bearer",
        expires_in: expires_in
      })
    end
  end
end
