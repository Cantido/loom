defmodule Loom.Subscriptions.WebhookWorker do
  use Oban.Worker,
    queue: :webhooks

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => id, "event_json" => event, "stream" => stream, "revision" => revision}}) do
    webhook = Loom.Subscriptions.get_webhook!(id)

    {:ok, _resp} =
      Loom.Subscriptions.WebhookClient.push(webhook, event, stream, revision)
  end
end
