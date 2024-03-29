defmodule Loom.MixProject do
  use Mix.Project

  def project do
    [
      app: :loom,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:boundary] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Loom.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:argon2_elixir, "~> 4.0"},
      {:benchfella, "~> 0.3.0"},
      {:boundary, "~> 0.9", runtime: false},
      {:cloudevents, "~> 0.6.1"},
      {:credo, ">= 0.0.0", only: [:dev], runtime: false},
      {:contex, "~> 0.5.0"},
      {:decorator, "~> 1.4"},
      {:ecto_sql, "~> 3.6"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_check, "~> 0.15.0", only: [:dev], runtime: false},
      {:ex_cldr, "~> 2.33"},
      {:ex_cldr_calendars, "~> 1.21"},
      {:ex_cldr_dates_times, "~> 2.13"},
      {:ex_cldr_numbers, "~> 2.28"},
      {:ex_cldr_plugs, "~> 1.2"},
      {:ex_cldr_units, "~> 3.15"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:explorer, "~> 0.8.0"},
      {:faker, "~> 0.17", only: :test},
      {:finch, "~> 0.18.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.18"},
      {:guardian, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:hammer, "~> 6.1"},
      {:hammer_plug, "~> 3.0"},
      {:jason, "~> 1.2"},
      {:nebulex, "~> 2.4"},
      {:nimble_options, "~> 1.0"},
      {:oban, "~> 2.17.1"},
      {:opentelemetry, "~> 1.0"},
      {:opentelemetry_api, "~> 1.1"},
      {:opentelemetry_ecto, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_oban, "~> 1.0"},
      {:opentelemetry_phoenix, "~> 1.0"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5"},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:sweet_xml, "~> 0.7.3"},
      {:swoosh, "~> 1.3"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:tesla, "~> 1.8.0"},
      {:timex, "~> 3.0"},
      {:uniq, "~> 0.6.0", only: [:dev, :test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd --cd assets npm install"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["cmd --cd assets node build.js --deploy", "phx.digest"]
    ]
  end
end
