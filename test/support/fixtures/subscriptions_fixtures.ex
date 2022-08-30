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
        url: "https://example.com/event_hook"
      })
      |> Loom.Subscriptions.create_webhook()

    webhook
  end
end