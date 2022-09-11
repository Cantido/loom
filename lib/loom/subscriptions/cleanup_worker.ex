defmodule Loom.Subscriptions.CleanupWorker do
  @moduledoc """
  A scheduled `Oban` worker that deletes a webhook unless it is validated.
  """

  use Oban.Worker

  alias Loom.Subscriptions

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => id}}) do
    webhook = Subscriptions.get_webhook!(id)

    unless webhook.validated do
      Subscriptions.delete_webhook(webhook)
    end
  end
end
