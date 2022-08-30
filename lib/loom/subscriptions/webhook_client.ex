defmodule Loom.Subscriptions.WebhookClient do
  use Tesla

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
