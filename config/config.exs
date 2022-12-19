# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :loom,
  ecto_repos: [Loom.Repo],
  webhook_cleanup_timeout: :timer.minutes(24 * 60)

config :loom, Loom.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec]

# Configures the endpoint
config :loom, LoomWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: LoomWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Loom.PubSub,
  live_view: [signing_salt: "s5k+OXb6"]

config :loom, Oban,
  repo: Loom.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    webhooks: 100
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :loom, Loom.Mailer, adapter: Swoosh.Adapters.Local

config :loom, LoomWeb.Tokens, issuer: "loom"

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :tesla, adapter: Tesla.Adapter.Finch

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

config :ex_cldr,
  default_backend: Loom.Cldr

config :ex_cldr_units,
  default_backend: Loom.Cldr

config :gettext,
  default_locale: "en"

config :mime, :types, %{
  "application/cloudevents+json" => ["json-cloudevents"],
  "application/cloudevents-batch+json" => ["json-cloudevents-batch"]
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
