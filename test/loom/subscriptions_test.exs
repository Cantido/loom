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
      team = team_fixture()
      webhook = webhook_fixture(%{team: team})
      assert List.first(Subscriptions.list_webhooks(team)).id == webhook.id
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

      assert {:ok, %Webhook{} = webhook} = Subscriptions.create_webhook(team_fixture(), valid_attrs)
      assert webhook.token == "some token"
      assert webhook.type == "some type"
      assert webhook.url == "https://example.com/event_hook"
    end

    test "create_webhook/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscriptions.create_webhook(team_fixture(), @invalid_attrs)
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
    alias Loom.Subscriptions.WebhookWorker
    alias Loom.Subscriptions.ValidationWorker

    import Loom.AccountsFixtures
    import Loom.StoreFixtures

    @source "loom-subscriptions-test"

    setup do
      team = team_fixture()
      source = source_fixture(%{team: team, source: @source})

      %{source: source, team: team}
    end

    test "a webhook makes a web request when an event is created", %{team: team} do
      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook",
        validated: true,
        allowed_rate: 100
      }

      {:ok, _} = Subscriptions.create_webhook(team, webhook_attrs)

      event = %{
        id: "webhook-request-event",
        source: @source,
        type: "com.example.event",
        specversion: "1.0"
      }

      {:ok, _} = Loom.append(event, team)

      assert_enqueued worker: WebhookWorker
    end

    test "a webhook is not triggered when it is not yet validated", %{team: team} do
      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook",
        validated: false
      }

      {:ok, _} = Subscriptions.create_webhook(team, webhook_attrs)

      event = %{
        id: "webhook-request-event",
        source: @source,
        type: "com.example.event",
        specversion: "1.0"
      }

      {:ok, _} = Loom.append(event, team)

      refute_enqueued worker: WebhookWorker
    end

    test "a webhook is validated before being created" do
      team = team_fixture()

      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook"
      }

      {:ok, %{id: id}} = Subscriptions.create_webhook(team, webhook_attrs)

      assert_enqueued worker: ValidationWorker
    end

    test "a webhook can be validated asynchronously", %{team: team} do
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

      Oban.Testing.with_testing_mode(:inline, fn ->
        {:ok, %{id: id}} = Subscriptions.create_webhook(team, webhook_attrs, cleanup_after: :never)

        # we do have to fetch the webhook again, since create_webhook only returns the webhook it created, before the job ran

        assert_receive {^test_ref, callback_url}

        assert callback_url =~ "http://localhost:4002/api/webhooks/#{id}/confirm"

        {:ok, webhook} =
          Subscriptions.get_webhook!(id) |> Subscriptions.validate_webhook("localhost")

        assert webhook.validated
      end)
    end

    test "a webhook is cleaned up after an amount of time if it isn't validated", %{team: team} do
      webhook_attrs = %{
        token: "some token",
        type: "com.example.event",
        url: "https://example.com/events/hook"
      }

      test_pid = self()
      test_ref = make_ref()

      mock(fn %{method: :options} ->
        send(test_pid, test_ref)

        %Tesla.Env{status: 200}
      end)

      Oban.Testing.with_testing_mode(:inline, fn ->
        {:ok, %{id: _id}} = Subscriptions.create_webhook(team, webhook_attrs, cleanup_after: 0)
      end)

      assert_receive ^test_ref

      assert Enum.empty?(Subscriptions.list_webhooks(team))
    end
  end

  describe "subscriptions" do
    alias Loom.Subscriptions.Subscription

    import Loom.SubscriptionsFixtures

    @invalid_attrs %{config: nil, filters: nil, protocol: nil, protocolsettings: nil, sink: nil, sink_credential: nil, source: nil, types: nil}

    test "list_subscriptions/0 returns all subscriptions" do
      subscription = subscription_fixture()
      assert List.first(Subscriptions.list_subscriptions()).id == subscription.id
    end

    test "get_subscription!/1 returns the subscription with given id" do
      subscription = subscription_fixture()
      assert Subscriptions.get_subscription!(subscription.id).id == subscription.id
    end

    test "create_subscription/1 with valid data creates a subscription" do
      source = Uniq.UUID.uuid7(:urn)
      valid_attrs = %{config: %{"rate" => "100"}, filters: %{}, protocol: "HTTPS", protocolsettings: %{"setting" => "a"}, sink: "some sink", sink_credential: %{"cred" => "a"}, source: %{source: source, team: %{name: Uniq.UUID.uuid7()}}, types: []}

      assert {:ok, %Subscription{} = subscription} = Subscriptions.create_subscription(valid_attrs)
      assert subscription.config == %{"rate" => "100"}
      assert subscription.filters == %{}
      assert subscription.protocol == "HTTPS"
      assert subscription.protocolsettings == %{"setting" => "a"}
      assert subscription.sink == "some sink"
      assert subscription.sink_credential == %{"cred" => "a"}
      assert subscription.source.source == source
      assert subscription.types == []
    end

    test "create_subscription/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscriptions.create_subscription(@invalid_attrs)
    end

    test "update_subscription/2 with valid data updates the subscription" do
      source = Uniq.UUID.uuid7(:urn)
      subscription = subscription_fixture()
      update_attrs = %{config: %{"rate" => "200"}, filters: %{}, protocol: "KAFKA", protocolsettings: %{"setting" => "b"}, sink: "some updated sink", sink_credential: %{"cred" => "b"}, source: %{source: source, team: %{name: Uniq.UUID.uuid4()}}, types: []}

      assert {:ok, %Subscription{} = subscription} = Subscriptions.update_subscription(subscription, update_attrs)
      assert subscription.config == %{"rate" => "200"}
      assert subscription.filters == %{}
      assert subscription.protocol == "KAFKA"
      assert subscription.protocolsettings == %{"setting" => "b"}
      assert subscription.sink == "some updated sink"
      assert subscription.sink_credential == %{"cred" => "b"}
      assert subscription.source.source == source
      assert subscription.types == []
    end

    test "update_subscription/2 with invalid data returns error changeset" do
      subscription = subscription_fixture()
      assert {:error, %Ecto.Changeset{}} = Subscriptions.update_subscription(subscription, @invalid_attrs)
      assert subscription.id == Subscriptions.get_subscription!(subscription.id).id
    end

    test "delete_subscription/1 deletes the subscription" do
      subscription = subscription_fixture()
      assert {:ok, %Subscription{}} = Subscriptions.delete_subscription(subscription)
      assert_raise Ecto.NoResultsError, fn -> Subscriptions.get_subscription!(subscription.id) end
    end

    test "change_subscription/1 returns a subscription changeset" do
      subscription = subscription_fixture()
      assert %Ecto.Changeset{} = Subscriptions.change_subscription(subscription)
    end
  end
end
