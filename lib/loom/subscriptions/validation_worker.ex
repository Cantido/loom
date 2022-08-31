defmodule Loom.Subscriptions.ValidationWorker do
  use Oban.Worker

  alias Loom.Subscriptions

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => webhook_id}}) do
    webhook = Subscriptions.get_webhook!(webhook_id)

    {:ok, resp} = Loom.Subscriptions.WebhookClient.validate(webhook)

    Logger.debug("Validator got resp: #{inspect resp, pretty: true}")


    origin_header = Tesla.get_header(resp, "webhook-allowed-origin")
    rate_limit_header = Tesla.get_header(resp, "webhook-allowed-rate")

    if not is_nil(origin_header) and not is_nil(rate_limit_header) do
      webhook_params = %{
        validated: true,
        allowed_rate: rate_limit_header
      }
      Subscriptions.update_webhook(webhook, webhook_params)
    end
  end
end
