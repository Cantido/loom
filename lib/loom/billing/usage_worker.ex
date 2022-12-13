defmodule Loom.Billing.UsageWorker do
  use Oban.Worker

  alias Stripe.SubscriptionItem.Usage

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    {:ok, datetime, _} = DateTime.from_iso8601(args["timestamp"])
    timestamp = DateTime.to_unix(datetime)

    {:ok, _sub} = Usage.create(args["sub_item_id"], %{quantity: 1, timestamp: timestamp})

    :ok
  end
end
