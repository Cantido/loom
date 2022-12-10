defmodule LoomWeb.Tokens do
  @moduledoc """
  A `Guardian` module for generating authentication tokens.

  Loom uses two different subjects for auth tokens:

  - `Loom.Accounts.User` structs, for browser authentication
  - `Loom.Accounts.Token` structs, for API authentication

  Subjects are formatted as strings starting with either `"user:"` or `"token:"` followed by the struct's Ecto UUID, formatted as a 22-character, base64-encoded slug.

  ## Examples

      iex> LoomWeb.Tokens.subject_for_token(%Loom.Accounts.User{id: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"})
      {:ok, "user:a6e4EJ2tEdGAtADAT9QwyA"}
  """
  use Guardian, otp_app: :loom

  alias Loom.Accounts
  alias Loom.Accounts.Token
  alias Loom.Accounts.User

  require Logger

  def subject_for_token(%Token{id: id}, _claims) do
    case Uniq.UUID.parse(id) do
      {:ok, uuid} ->
        slug = Uniq.UUID.to_string(uuid, :slug)

        {:ok, "token:" <> slug}

      err ->
        err
    end
  end

  def subject_for_token(%User{id: id}, _claims) do
    case Uniq.UUID.parse(id) do
      {:ok, uuid} ->
        slug = Uniq.UUID.to_string(uuid, :slug)

        {:ok, "user:" <> slug}

      err ->
        err
    end
  end

  def resource_from_claims(%{"sub" => "token:" <> slug}) do
    case Uniq.UUID.parse(slug) do
      {:ok, id} ->
        token = Accounts.get_token!(Uniq.UUID.to_string(id, :default))
        {:ok, token}

      err ->
        err
    end
  end

  def resource_from_claims(%{"sub" => "user:" <> slug}) do
    case Uniq.UUID.parse(slug) do
      {:ok, id} ->
        user = Accounts.get_user!(Uniq.UUID.to_string(id, :default))
        {:ok, user}

      err ->
        err
    end
  end

  def build_claims(claims, %Token{} = token, _opts) do
    {:ok, Map.put(claims, :client_id, token.username)}
  end

  def build_claims(claims, _, _) do
    {:ok, claims}
  end
end
