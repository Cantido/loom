VERSION 0.6

ARG MIX_ENV=dev

all:
  BUILD +check
  BUILD +test
  BUILD +docker

deps:
  FROM elixir:1.13
  ARG MIX_ENV
  COPY mix.exs .
  COPY mix.lock .

  RUN apt update \
      && apt upgrade -y \
      && mix local.rebar --force \
      && mix local.hex --force \
      && mix deps.get \
      && mix deps.compile

build:
  FROM +deps

  COPY --dir lib/ test/ config/ priv/ ./
  RUN mix compile

check:
  FROM +build --MIX_ENV=dev

  RUN mix check --except ex_unit

test:
  FROM +build --MIX_ENV=test

  COPY docker-compose.yml .

  WITH DOCKER --compose docker-compose.yml
    RUN mix check --only ex_unit
  END

release:
  FROM +build

  RUN mix release

  SAVE ARTIFACT _build/$MIX_ENV/rel

docker:
  FROM debian:bullseye
  WORKDIR /app

  RUN apt update && apt upgrade -y \
    && apt install -y locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

  ENV LANG en_US.UTF-8
  ENV LANGUAGE en_US:en
  ENV LC_ALL en_US.UTF-8

  COPY --dir --build-arg MIX_ENV=prod +release/rel .

  ENTRYPOINT ["/app/rel/loom/bin/loom"]
  CMD ["start"]

  SAVE IMAGE --push ghcr.io/cantido/loom:latest
