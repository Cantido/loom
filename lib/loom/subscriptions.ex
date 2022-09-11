defmodule Loom.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  """

  import Ecto.Query, warn: false
  alias Loom.Repo

  alias Loom.Subscriptions.Webhook

  require Logger

  @doc """
  Returns the list of webhooks.

  ## Examples

      iex> list_webhooks()
      [%Webhook{}, ...]

  """
  def list_webhooks do
    Repo.all(Webhook)
  end

  @doc """
  Gets a single webhook.

  Raises `Ecto.NoResultsError` if the Webhook does not exist.

  ## Examples

      iex> get_webhook!(123)
      %Webhook{}

      iex> get_webhook!(456)
      ** (Ecto.NoResultsError)

  """
  def get_webhook!(id), do: Repo.get!(Webhook, id)

  @doc """
  Gets a single webhook.

  ## Examples

      iex> get_webhook(123)
      {:ok, %Webhook{}}

      iex> get_webhook(456)
      {:error, :not_found}

  """
  def get_webhook(id) do
    if webhook = Repo.get(Webhook, id) do
      {:ok, webhook}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Creates a webhook.

  ## Examples

      iex> create_webhook(%{field: value})
      {:ok, %Webhook{}}

      iex> create_webhook(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_webhook(attrs \\ %{}, opts \\ []) do
    %Webhook{}
    |> Webhook.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, webhook} ->
        start_webhook_jobs(webhook, opts)
        {:ok, webhook}

      err ->
        err
    end
  end

  defp start_webhook_jobs(webhook, opts) do
    unless webhook.validated do
      args = %{webhook_id: webhook.id}

      Loom.Subscriptions.ValidationWorker.new(args)
      |> Oban.insert!()

      cleanup_after =
        Keyword.get(
          opts,
          :cleanup_after,
          Application.fetch_env!(:loom, :webhook_cleanup_timeout)
        )

      unless cleanup_after == :never do
        Loom.Subscriptions.CleanupWorker.new(args, schedule_in: cleanup_after)
        |> Oban.insert!()
      end
    end
  end

  @doc """
  Updates a webhook.

  ## Examples

      iex> update_webhook(webhook, %{field: new_value})
      {:ok, %Webhook{}}

      iex> update_webhook(webhook, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_webhook(%Webhook{} = webhook, attrs) do
    webhook
    |> Webhook.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a webhook.

  ## Examples

      iex> delete_webhook(webhook)
      {:ok, %Webhook{}}

      iex> delete_webhook(webhook)
      {:error, %Ecto.Changeset{}}

  """
  def delete_webhook(%Webhook{} = webhook) do
    Repo.delete(webhook)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking webhook changes.

  ## Examples

      iex> change_webhook(webhook)
      %Ecto.Changeset{data: %Webhook{}}

  """
  def change_webhook(%Webhook{} = webhook, attrs \\ %{}) do
    Webhook.changeset(webhook, attrs)
  end

  def send_webhooks(event) do
    webhooks = Loom.Repo.all(from w in Webhook, where: w.type == ^event.type, where: w.validated)
    Logger.info("Got #{Enum.count(webhooks)} webhooks for type #{event.type}")

    event_json = Cloudevents.to_json(event)

    Enum.each(webhooks, fn webhook ->
      %{
        webhook_id: webhook.id,
        event_json: event_json
      }
      |> Loom.Subscriptions.WebhookWorker.new()
      |> Oban.insert()
    end)
  end

  def validate_webhook(%Webhook{} = webhook, allowed_origin, opts \\ []) do
    expected_origin = Application.fetch_env!(:loom, :webhook_request_origin)

    if allowed_origin in [expected_origin, "*"] do
      args = %{
        validated: true,
        allowed_rate: Keyword.get(opts, :allowed_rate, 120)
      }

      update_webhook(webhook, args)
    else
      {:error, "WebHook-Allowed-Origin header must be equal to #{expected_origin} or *"}
    end
  end
end
