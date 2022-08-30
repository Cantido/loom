defmodule Loom.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Loom.Cache,
      Loom.Repo,
      LoomWeb.Telemetry,
      {Finch, name: Loom.Finch},
      {Phoenix.PubSub, name: Loom.PubSub},
      LoomWeb.Endpoint,
      {Oban, Application.fetch_env!(:loom, Oban)}
    ]

    opts = [strategy: :one_for_one, name: Loom.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LoomWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
