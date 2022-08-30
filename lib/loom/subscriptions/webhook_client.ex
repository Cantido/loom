defmodule Loom.Subscriptions.WebhookClient do
  use Tesla

  def push(webhook, event_json, stream, revision) do
    post(webhook.url, event_json, headers: [{"x-loom-stream", stream}, {"x-loom-revision", Integer.to_string(revision)}])
  end
end
