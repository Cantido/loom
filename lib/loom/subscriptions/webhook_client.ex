defmodule Loom.Subscriptions.WebhookClient do
  @moduledoc """
  A `Tesla` client for making webhook requests.

  Handles both validation requests as well as publish requests.
  """

  use Tesla

  def validate(webhook) do
    origin = Application.fetch_env!(:loom, :webhook_request_origin)

    callback =
      Application.fetch_env!(:loom, :webhook_request_callback)
      |> String.replace("%3Awebhook_id", webhook.id)

    headers = [
      {"webhook-request-callback", callback},
      {"webhook-request-origin", origin}
    ]

    options(webhook.url, headers: headers)
  end

  def push(webhook, event_json) do
    headers = [
      {"content-type", "application/cloudevents+json; charset=utf-8"},
      {"authorization", "Bearer #{webhook.token}"}
    ]

    post(webhook.url, event_json, headers: headers)
  end
end
