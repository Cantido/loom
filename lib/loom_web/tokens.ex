defmodule LoomWeb.Tokens do
  use Guardian, otp_app: :loom

  alias Loom.Accounts
  alias Loom.Accounts.Token

  require Logger

  def subject_for_token(%Token{id: id}, _claims) do
    Logger.info("making jwt for token #{id}")

    {:ok, id}
  end

  def resource_from_claims(%{"sub" => id}) do
    Logger.info("getting token #{id}")

    token = Accounts.get_token!(id)
    {:ok, token}
  end

  def build_claims(claims, %Token{} = token, _opts) do
    {:ok, Map.put(claims, :client_id, token.username)}
  end
end
