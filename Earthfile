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

  COPY --dir config/ lib/ test/ ./

  RUN mix test
