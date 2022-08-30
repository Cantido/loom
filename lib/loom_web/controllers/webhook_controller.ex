defmodule LoomWeb.WebhookController do
  use LoomWeb, :controller

  alias Loom.Subscriptions
  alias Loom.Subscriptions.Webhook

  action_fallback LoomWeb.FallbackController

  def index(conn, _params) do
    webhooks = Subscriptions.list_webhooks()
    render(conn, "index.json", webhooks: webhooks)
  end

  def create(conn, %{"webhook" => webhook_params}) do
    with {:ok, %Webhook{} = webhook} <- Subscriptions.create_webhook(webhook_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.webhook_path(conn, :show, webhook))
      |> render("show.json", webhook: webhook)
    end
  end

  def show(conn, %{"id" => id}) do
    webhook = Subscriptions.get_webhook!(id)
    render(conn, "show.json", webhook: webhook)
  end

  def update(conn, %{"id" => id, "webhook" => webhook_params}) do
    webhook = Subscriptions.get_webhook!(id)

    with {:ok, %Webhook{} = webhook} <- Subscriptions.update_webhook(webhook, webhook_params) do
      render(conn, "show.json", webhook: webhook)
    end
  end

  def delete(conn, %{"id" => id}) do
    webhook = Subscriptions.get_webhook!(id)

    with {:ok, %Webhook{}} <- Subscriptions.delete_webhook(webhook) do
      send_resp(conn, :no_content, "")
    end
  end
end