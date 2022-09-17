defmodule Loom.SubscriptionsTest do
  use Loom.DataCase

  alias Loom.Subscriptions

  import Tesla.Mock

  @source "loom-subscriptions-test"

  describe "CRUD webhooks" do
    alias Loom.Subscriptions.Webhook

    import Loom.AccountsFixtures
    import Loom.SubscriptionsFixtures

    @invalid_attrs %{token: nil, type: nil, url: nil}

    test "list_webhooks/0 returns all webhooks" do
      account = account_fixture()
      webhook = webhook_fixture(%{account: account})
      assert List.first(Subscriptions.list_webhooks(account)).id == webhook.id
    end

    test "get_webhook!/1 returns the webhook with given id" do
      webhook = webhook_fixture()
      assert Subscriptions.get_webhook!(webhook.id).id == webhook.id
    end

    test "create_webhook/1 with valid data creates a webhook" do
      valid_attrs = %{
        token: "some token",
        type: "some type",
        url: "https://example.com/event_hook",
        validated: true
      }

      assert {:ok, %Webhook{} = webhook} = Subscriptions.create_webhook(account_fixture(), valid_attrs)
      assert webhook.token == "some token"
      assert webhook.type == "some type"
      assert webhook.url == "https://example.com/event_hook"
    end

    test "create_webhook/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscriptions.create_webhook(account_fixture(), @invalid_attrs)
    end

    test "update_webhook/2 with valid data updates the webhook" do
      webhook = webhook_fixture()

      update_attrs = %{
        token: "some updated token",
        type: "some updated type",
        url: "https://example.com/updated_event_hook"
      }

      assert {:ok, %Webhook{} = webhook} = Subscriptions.update_webhook(webhook, update_attrs)
      assert webhook.token == "some updated token"
      assert webhook.type == "some updated type"
      assert webhook.url == "https://example.com/updated_event_hook"
    end

    test "update_webhook/2 with invalid data returns error changeset" do
      webhook = webhook_fixture()
      assert {:error, %Ecto.Changeset{}} = Subscriptions.update_webhook(webhook, @invalid_attrs)
      assert webhook.id == Subscriptions.get_webhook!(webhook.id).id
    end

    test "delete_webhook/1 deletes the webhook" do
      webhook = webhook_fixture()
      assert {:ok, %Webhook{}} = Subscriptions.delete_webhook(webhook)
      assert_raise Ecto.NoResultsError, fn -> Subscriptions.get_webhook!(webhook.id) end
    end

    test "change_webhook/1 returns a webhook changeset" do
      webhook = webhook_fixture()
      assert %Ecto.Changeset{} = Subscriptions.change_webhook(webhook)
    end
  end

  describe "webhook behaviour" do
    import Loom.AccountsFixtures
    import Loom.StoreFixtures

    @source "loom-subscriptions-test"

    setup do
      account = account_fixture()
      source = source_fixture(%{account: account, source: @source})

      %{source: source, account: account}
    end

    test "a webhook makes a web request when an event is created", %{account: account} do
      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook",
        validated: true,
        allowed_rate: 100
      }

      test_pid = self()
      test_ref = make_ref()

      mock(fn %{method: :post, url: url, body: body} = env ->
        send(test_pid, test_ref)

        {:ok, event} = Cloudevents.from_json(body)
        assert event.id == "webhook-request-event"

        assert "application/cloudevents+json; charset=utf-8" ==
                 Tesla.get_header(env, "content-type")

        assert "Bearer some token" == Tesla.get_header(env, "authorization")
        %Tesla.Env{status: 200}
      end)

      {:ok, _} = Subscriptions.create_webhook(account, webhook_attrs)

      event =
        Cloudevents.from_map!(%{
          id: "webhook-request-event",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      {:ok, _} = Loom.append(event, account)

      assert_receive ^test_ref
    end

    test "a webhook is not triggered when it is not yet validated", %{account: account} do
      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook",
        validated: false
      }

      mock(fn
        %{method: :put} -> flunk("This webhook shouldn't have been published to")
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = Subscriptions.create_webhook(account, webhook_attrs)
      end)

      event =
        Cloudevents.from_map!(%{
          id: "webhook-request-event",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      {:ok, _} = Loom.append(event, account)
    end

    test "a webhook is validated before being created" do
      account = account_fixture()

      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook"
      }

      test_pid = self()
      test_ref = make_ref()

      mock(fn %{method: :options} = env ->
        send(test_pid, test_ref)

        origin = Tesla.get_header(env, "webhook-request-origin")

        assert origin == "localhost"

        %Tesla.Env{
          status: 200,
          headers: [{"webhook-allowed-origin", origin}, {"webhook-allowed-rate", 100}]
        }
      end)

      {:ok, %{id: id}} = Subscriptions.create_webhook(account, webhook_attrs)

      # We're in a test and Oban is set to inline jobs, so the validation was run synchronously after creating the webhook

      # But we do have to fetch the webhook again, since create_webhook only returns the webhook it created, before the job ran

      assert_receive ^test_ref

      webhook = Subscriptions.get_webhook!(id)

      assert webhook.validated
    end

    test "a webhook can be validated asynchronously", %{account: account} do
      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook"
      }

      test_pid = self()
      test_ref = make_ref()

      mock(fn %{method: :options} = env ->
        send(test_pid, {test_ref, Tesla.get_header(env, "webhook-request-callback")})

        %Tesla.Env{status: 200}
      end)

      {:ok, %{id: id}} = Subscriptions.create_webhook(account, webhook_attrs, cleanup_after: :never)

      # We're in a test and Oban is set to inline jobs, so the validation was run synchronously after creating the webhook

      # But we do have to fetch the webhook again, since create_webhook only returns the webhook it created, before the job ran

      assert_receive {^test_ref, callback_url}

      assert callback_url =~ "http://localhost:4002/api/webhooks/#{id}/confirm"

      {:ok, webhook} =
        Subscriptions.get_webhook!(id) |> Subscriptions.validate_webhook("localhost")

      assert webhook.validated
    end

    test "a webhook is cleaned up after an amount of time if it isn't validated", %{account: account} do
      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook"
      }

      test_pid = self()
      test_ref = make_ref()

      mock(fn %{method: :options} = env ->
        send(test_pid, test_ref)

        %Tesla.Env{status: 200}
      end)

      {:ok, %{id: id}} = Subscriptions.create_webhook(account, webhook_attrs, cleanup_after: 0)

      # We're in a test and Oban is set to inline jobs, so the validation was run synchronously after creating the webhook, and then cleanup ran to delete it.

      # But we do have to fetch the webhook again, since create_webhook only returns the webhook it created, before the job ran

      assert_receive ^test_ref

      assert Enum.empty?(Subscriptions.list_webhooks(account))
    end
  end
end
