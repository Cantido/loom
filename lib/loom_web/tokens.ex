defmodule LoomWeb.Tokens do
  @moduledoc """
  A `Guardian` module for generating authentication tokens.
  """
  use Guardian, otp_app: :loom

  alias Loom.Accounts
  alias Loom.Accounts.Token

  def subject_for_token(%Token{id: id}, _claims) do
    {:ok, id}
  end

  def resource_from_claims(%{"sub" => id}) do
    token = Accounts.get_token!(id)
    {:ok, token}
  end

  def build_claims(claims, %Token{} = token, _opts) do
    {:ok, Map.put(claims, :client_id, token.username)}
  end

  def build_claims(claims, _, _) do
    {:ok, claims}
  end
end
