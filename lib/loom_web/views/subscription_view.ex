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
      source: subscription.source.source,
      types: subscription.types,
      config: subscription.config,
      filters: subscription.filters,
      sink: subscription.sink,
      sink_credential: subscription.sink_credential,
      protocol: subscription.protocol,
      protocolsettings: subscription.protocolsettings
    }
  end
end
