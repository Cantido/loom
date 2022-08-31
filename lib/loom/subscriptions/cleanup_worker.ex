defmodule Loom.Subscriptions.CleanupWorker do
  use Oban.Worker

  alias Loom.Subscriptions

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => id}}) do
    webhook = Subscriptions.get_webhook!(id)

    unless webhook.validated do
      Subscriptions.delete_webhook(webhook)
    end
  end
end
