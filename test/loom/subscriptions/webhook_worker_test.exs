defmodule Loom.Subscriptions.WebhookWorkerTest do
  use Loom.DataCase, async: true
  use Oban.Testing, repo: Loom.Repo

  alias Loom.Subscriptions

  import Tesla.Mock

  test "sends the event to the webhook target" do
    webhook_attrs = %{
      token: "some token",
      type: "com.example.event",
      url: "https://example.com/events/hook",
      validated: true,
      allowed_rate: 100
    }

    mock(fn env ->
      event = Cloudevents.from_json!(env.body)
      assert event.id == "webhook-worker-test"
      %Tesla.Env{status: 200}
    end)


    {:ok, webhook} = Subscriptions.create_webhook(webhook_attrs)

    event = Cloudevents.from_map!(%{id: "webhook-worker-test", source: "webhook-tests", type: "com.example.event", specversion: "1.0"})

    :ok =
      perform_job(
        Loom.Subscriptions.WebhookWorker,
        %{
          webhook_id: webhook.id,
          event_json: Cloudevents.to_json(event),
          stream: "my-stream",
          revision: 1000
        }
      )
  end

  test "cancels the job if the webhook does not exist " do
    event = Cloudevents.from_map!(%{id: "webhook-worker-test", source: "webhook-tests", type: "com.example.event", specversion: "1.0"})

    {:cancel, "webhook not found"} =
      perform_job(
        Loom.Subscriptions.WebhookWorker,
        %{
          webhook_id: "50f87e1d-d5c7-4f31-a9df-04090bbf2a5e",
          event_json: Cloudevents.to_json(event),
          stream: "my-stream",
          revision: 1000
        }
      )
  end

  test "deletes the webhook when we get a 410 Gone response" do
    webhook_attrs = %{
      token: "some token",
      type: "com.example.event",
      url: "https://example.com/events/hook",
      validated: true,
      allowed_rate: 100
    }

    mock(fn env ->
      %Tesla.Env{status: 410}
    end)

    {:ok, webhook} = Subscriptions.create_webhook(webhook_attrs)

    event = Cloudevents.from_map!(%{id: "webhook-worker-test", source: "webhook-tests", type: "com.example.event", specversion: "1.0"})

    :ok =
      perform_job(
        Loom.Subscriptions.WebhookWorker,
        %{
          webhook_id: webhook.id,
          event_json: Cloudevents.to_json(event),
          stream: "my-stream",
          revision: 1000
        }
      )

    assert {:error, :not_found} == Loom.Subscriptions.get_webhook(webhook.id)
  end

  test "snoozes the job if we get a 429 Too Many Requests response" do
    webhook_attrs = %{
      token: "some token",
      type: "com.example.event",
      url: "https://example.com/events/hook",
      validated: true,
      allowed_rate: 100
    }

    mock(fn env ->
      retry_after =
        Timex.now()
        |> Timex.shift(minutes: 1)
        |> Timex.format!("{RFC1123}")

      %Tesla.Env{status: 429, headers: [{"retry-after", retry_after}]}
    end)

    {:ok, webhook} = Subscriptions.create_webhook(webhook_attrs)

    event = Cloudevents.from_map!(%{id: "webhook-worker-test", source: "webhook-tests", type: "com.example.event", specversion: "1.0"})

    {:snooze, _} =
      perform_job(
        Loom.Subscriptions.WebhookWorker,
        %{
          webhook_id: webhook.id,
          event_json: Cloudevents.to_json(event),
          stream: "my-stream",
          revision: 1000
        }
      )
  end


  test "snoozes if we need to rate-limit" do
    webhook_attrs = %{
      token: "some token",
      type: "com.example.event",
      url: "https://example.com/events/hook",
      validated: true,
      allowed_rate: 100
    }

    mock(fn env ->
      assert env.url == webhook_attrs.url
      event = Cloudevents.from_json!(env.body)
      assert event.id == "webhook-worker-test"
      %Tesla.Env{status: 200}
    end)


    {:ok, webhook} = Subscriptions.create_webhook(webhook_attrs)

    {:allow, _} = Hammer.check_rate_inc("webhook_push:#{webhook.id}", :timer.minutes(1), webhook.allowed_rate, webhook.allowed_rate)
    event = Cloudevents.from_map!(%{id: "webhook-worker-test", source: "webhook-tests", type: "com.example.event", specversion: "1.0"})

    {:snooze, snooze_amt} =
      perform_job(
        Loom.Subscriptions.WebhookWorker,
        %{
          webhook_id: webhook.id,
          event_json: Cloudevents.to_json(event),
          stream: "my-stream",
          revision: 1000
        }
      )
    assert snooze_amt > 0
  end


end
