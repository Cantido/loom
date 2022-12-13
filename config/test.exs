import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :loom, Loom.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "loom_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  log: false

config :loom, Oban, testing: :manual

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :loom, LoomWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6IEsuSnAYG64JfUj6PMrDElALjsZUP3xQL0XXl6wwcNIOVma4qUGgh8EWq1CG0gP",
  server: false

# In test we don't send emails.
config :loom, Loom.Mailer, adapter: Swoosh.Adapters.Test

config :loom, LoomWeb.Tokens, secret_key: "Ptb1BlnxoC0lmwRjo1QVIhk4zHqc3EZN40thOxIDeO957JX/BG/dMOEUCxGlA1c+"

config :logger, level: :debug

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :tesla, adapter: Tesla.Mock
