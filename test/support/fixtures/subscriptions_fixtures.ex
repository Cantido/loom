defmodule Loom.SubscriptionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loom.Subscriptions` context.
  """

  import Loom.AccountsFixtures

  @doc """
  Generate a webhook.
  """
  def webhook_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        token: "some token",
        type: "some type",
        url: "https://example.com/event_hook",
        validated: true,
        allowed_rate: 100
      })
    account = Map.get(attrs, :account, account_fixture())
    {:ok, webhook} =
      Loom.Subscriptions.create_webhook(account, attrs)

    webhook
  end
end
