defmodule Loom.Subscriptions.WebhookClient do
  use Tesla

  def validate(webhook) do
    origin = Application.fetch_env!(:loom, :webhook_request_origin)
    options(webhook.url, headers: [{"webhook-request-origin", origin}])
  end

  def push(webhook, event_json, stream, revision) do
    headers = [
      {"x-loom-stream", stream},
      {"x-loom-revision", Integer.to_string(revision)},
      {"content-type", "application/cloudevents+json; charset=utf-8"},
      {"authorization", "Bearer #{webhook.token}"}
    ]
    post(webhook.url, event_json, headers: headers)
  end
end
