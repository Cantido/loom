defmodule Loom.Subscriptions.ValidationWorker do
  use Oban.Worker

  alias Loom.Subscriptions

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => webhook_id}}) do
    webhook = Subscriptions.get_webhook!(webhook_id)

    {:ok, resp} = Loom.Subscriptions.WebhookClient.validate(webhook)

    origin_header = Tesla.get_header(resp, "webhook-allowed-origin")
    rate_limit_header = Tesla.get_header(resp, "webhook-allowed-rate")

    opts = if is_nil(rate_limit_header), do: [], else: [allowed_rate: rate_limit_header]

    Subscriptions.validate_webhook(webhook, origin_header, opts)

    :ok
  end
end
