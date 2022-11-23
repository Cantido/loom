defmodule Loom.SubscriptionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loom.Subscriptions` context.
  """

  import Loom.AccountsFixtures
  import Loom.StoreFixtures

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
    team = Map.get(attrs, :team, team_fixture())
    {:ok, webhook} =
      Loom.Subscriptions.create_webhook(team, attrs)

    webhook
  end

  @doc """
  Generate a subscription.
  """
  def subscription_fixture(attrs \\ %{}) do
    {:ok, subscription} =
      attrs
      |> Enum.into(%{
        protocol: "HTTP",
        sink: "https://example.com/event_hook",
        source: %{source: Uniq.UUID.uuid7(:urn), team: %{name: Uniq.UUID.uuid7()}}
      })
      |> Loom.Subscriptions.create_subscription()

    subscription
  end
end
