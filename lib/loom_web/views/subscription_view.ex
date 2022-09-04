defmodule LoomWeb.SubscriptionView do
  use LoomWeb, :view
  alias LoomWeb.SubscriptionView

  def render("index.json", %{subscriptions: subscriptions}) do
    render_many(subscriptions, SubscriptionView, "subscription.json")
  end

  def render("show.json", %{subscription: subscription}) do
    render_one(subscription, SubscriptionView, "subscription.json")
  end

  def render("subscription.json", %{subscription: subscription}) do
    %{
      id: subscription.id,
      source: subscription.source,
      types: subscription.types,
      sink: subscription.sink,
      sinkCredential: subscription.sink_credentials,
      protocol: subscription.protocol,
      protocolsettings: subscription.protocol_settings,
      filters: render_many(subscription.filters, LoomWeb.FilterView, "filter.json"),
      config: subscription.config
    }
  end
end
