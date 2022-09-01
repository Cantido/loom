VERSION 0.6

ARG MIX_ENV=dev

all:
  BUILD +check

deps:
  FROM elixir:1.13
  ARG MIX_ENV
  COPY mix.exs .
  COPY mix.lock .

  RUN mix local.rebar --force \
      && mix local.hex --force \
      && mix deps.get \
      && mix deps.compile

check:
  FROM +deps --MIX_ENV=test

  COPY docker-compose.yml .
  COPY --dir lib/ test/ config/ priv/ ./

  WITH DOCKER --compose docker-compose.yml
    RUN mix test
  END
