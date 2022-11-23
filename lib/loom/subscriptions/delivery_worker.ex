defmodule Loom.Subscriptions.DeliveryWorker do
  @moduledoc """
  An `Oban` worker that publishes an event to an HTTP subscription.
  """

  use Oban.Worker,
    queue: :webhooks

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "subscription_id" => id,
          "event_json" => event
        }
      }) do
    with {:ok, subscription} <- Loom.Subscriptions.get_subscription!(id),
         {:ok, %{status: status}} when status in [200, 201, 202, 204] <-
           Loom.Subscriptions.WebhookClient.deliver(subscription.sink, event, "") do
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
