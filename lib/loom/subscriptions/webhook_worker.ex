defmodule Loom.Subscriptions.WebhookWorker do
  use Oban.Worker,
    queue: :webhooks

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => id, "event_json" => event, "stream" => stream, "revision" => revision}}) do
    webhook = Loom.Subscriptions.get_webhook!(id)

    with {:allow, _} <- Hammer.check_rate("webhook_push:#{id}", :timer.minutes(1), webhook.allowed_rate),
         {:ok, _resp} <- Loom.Subscriptions.WebhookClient.push(webhook, event, stream, revision) do
    else
      {:deny, _} ->
        {:snooze, 15}
      err ->
        err
    end
  end
end
