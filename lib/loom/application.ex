defmodule Loom.Application do
  @moduledoc false

  use Application
  use Boundary,
    top_level?: true,
    deps: [Loom, LoomWeb]

  @impl true
  def start(_type, _args) do
    OpentelemetryEcto.setup([:loom, :repo])
    OpentelemetryOban.setup()
    OpentelemetryPhoenix.setup()

    children = [
      Loom.Repo,
      LoomWeb.Telemetry,
      {Finch, name: Loom.Finch},
      {Phoenix.PubSub, name: Loom.PubSub},
      LoomWeb.Endpoint,
      {Oban, Application.fetch_env!(:loom, Oban)}
    ]

    opts = [strategy: :one_for_one, name: Loom.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Application.put_env(:loom, :webhook_request_origin, LoomWeb.Endpoint.host())

        Application.put_env(
          :loom,
          :webhook_request_callback,
          LoomWeb.Router.Helpers.webhook_confirm_url(LoomWeb.Endpoint, :confirm, ":webhook_id")
        )

        Application.put_env(:loom, :broadcast_endpoint, LoomWeb.Endpoint)

        ExAws.S3.put_bucket("events", "us-east-1")
        |> ExAws.request!()

        {:ok, pid}

      err ->
        err
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    LoomWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
