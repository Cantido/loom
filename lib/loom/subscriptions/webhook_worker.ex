defmodule Loom.Subscriptions.WebhookWorker do
  use Oban.Worker,
    queue: :webhooks

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "webhook_id" => id,
          "event_json" => event,
          "stream" => stream,
          "revision" => revision
        }
      }) do
    with {:ok, webhook} <- Loom.Subscriptions.get_webhook(id),
         {:allow, _} <-
           Hammer.check_rate("webhook_push:#{id}", :timer.minutes(1), webhook.allowed_rate),
         {:ok, %{status: status}} when status in [200, 201, 202, 204] <-
           Loom.Subscriptions.WebhookClient.push(webhook, event, stream, revision) do
      :ok
    else
      {:error, :not_found} ->
        {:cancel, "webhook not found"}

      {:deny, _} ->
        {:snooze, 15}

      {:ok, %Tesla.Env{status: 429} = env} ->
        retry_after =
          Tesla.get_header(env, "retry-after")
          |> Timex.parse!("{RFC1123}")

        seconds_to_snooze = Timex.diff(Timex.now(), retry_after, :seconds)
        {:snooze, seconds_to_snooze}

      {:ok, %Tesla.Env{}} ->
        {:ok, webhook} = Loom.Subscriptions.get_webhook(id)
        Loom.Subscriptions.delete_webhook(webhook)
        :ok

      err ->
        err
    end
  end
end
