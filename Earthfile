VERSION 0.6

all:
  BUILD +check

deps:
  FROM elixir:1.13
  COPY mix.exs .
  COPY mix.lock .
  RUN mix local.rebar --force \
      && mix local.hex --force \
      && mix deps.get

check:
  FROM +deps

  COPY docker-compose.yml .
  COPY --dir lib/ test/ config/ priv/ ./

  WITH DOCKER --compose docker-compose.yml
    RUN mix test
  END
