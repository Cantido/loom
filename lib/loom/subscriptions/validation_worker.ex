defmodule Loom.Subscriptions.ValidationWorker do
  use Oban.Worker

  alias Loom.Subscriptions

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => webhook_id}}) do
    webhook = Subscriptions.get_webhook!(webhook_id)

    resp = Loom.Subscriptions.WebhookClient.validate(webhook)

    Logger.debug("Validator got resp: #{inspect resp, pretty: true}")

    if affirmative_response?(resp) do
      Subscriptions.update_webhook(webhook, %{validated: true})
    else
      Subscriptions.delete_webhook(webhook)
    end
  end

  defp affirmative_response?({:ok, resp}) do
    affirmative_status = resp.status in [200, 201, 202]
    affirmative_allow = "POST" in allowed_methods(resp)
    Logger.debug("affirmative status: #{affirmative_status}, aff allow: #{affirmative_allow}")
    affirmative_status and affirmative_allow
  end

  defp affirmative_response?(_), do: false

  defp allowed_methods(resp) do
    Tesla.get_header(resp, "allow") |> String.split(", ")
  end
end
