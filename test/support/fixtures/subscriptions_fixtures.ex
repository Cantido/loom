defmodule Loom.SubscriptionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loom.Subscriptions` context.
  """

  @doc """
  Generate a webhook.
  """
  def webhook_fixture(attrs \\ %{}) do
    {:ok, webhook} =
      attrs
      |> Enum.into(%{
        token: "some token",
        type: "some type",
        url: "https://example.com/event_hook",
        validated: true,
        allowed_rate: 100
      })
      |> Loom.Subscriptions.create_webhook()

    webhook
  end

  @doc """
  Generate a subscription.
  """
  def subscription_fixture(attrs \\ %{}) do
    {:ok, subscription} =
      attrs
      |> Enum.into(%{
        filters: [
          %{"prefix" => %{"type" => "com.example."}}
        ],
        protocol: "HTTP",
        protocol_settings: %{"method" => "POST"},
        sink: "http://example.com/event-processor"
      })
      |> Loom.Subscriptions.create_subscription()

    subscription
  end
end
