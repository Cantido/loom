defmodule LoomWeb.SubscriptionView do
  use LoomWeb, :view
  alias LoomWeb.SubscriptionView

  def render("index.json", %{subscriptions: subscriptions}) do
    %{data: render_many(subscriptions, SubscriptionView, "subscription.json")}
  end

  def render("show.json", %{subscription: subscription}) do
    %{data: render_one(subscription, SubscriptionView, "subscription.json")}
  end

  def render("subscription.json", %{subscription: subscription}) do
    %{
      id: subscription.id,
      source: subscription.source,
      types: subscription.types,
      sink: subscription.sink,
      sink_credentials: subscription.sink_credentials,
      protocol: subscription.protocol,
      protocol_settings: subscription.protocol_settings,
      filters: subscription.filters,
      config: subscription.config
    }
  end
end
