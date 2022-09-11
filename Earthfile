VERSION 0.6

ARG MIX_ENV=dev

all:
  BUILD +check

deps:
  FROM elixir:1.13-alpine
  ARG MIX_ENV
  COPY mix.exs .
  COPY mix.lock .

  RUN apk --update-cache upgrade --available \
      && mix local.rebar --force \
      && mix local.hex --force \
      && mix deps.get \
      && mix deps.compile

build:
  FROM +deps

  COPY --dir lib/ test/ config/ priv/ ./
  RUN mix compile

check:
  FROM +build --MIX_ENV=test

  COPY docker-compose.yml .

  WITH DOCKER --compose docker-compose.yml
    RUN mix test
  END

release:
  FROM +build

  RUN mix release

  SAVE ARTIFACT _build/$MIX_ENV/rel

docker:
  FROM alpine
  WORKDIR /app

  RUN apk --update-cache upgrade --available \
      && apk add alpine-sdk ncurses

  COPY --dir --build-arg MIX_ENV=prod +release/rel .

  ENTRYPOINT ["/app/rel/loom/bin/loom"]
  CMD ["start"]

  SAVE IMAGE --push ghcr.io/cantido/loom:latest
