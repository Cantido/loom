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
      && mix deps.get

build:
  FROM +deps

  COPY --dir lib/ test/ config/ priv/ assets/ rel/ ./
  RUN mix compile

check:
  FROM +build --MIX_ENV=dev

  RUN mix check

test:
  FROM +build --MIX_ENV=test

  COPY docker-compose.yml .

  WITH DOCKER --compose docker-compose.yml
    RUN mix test
  END

release:
  FROM +build

  RUN mix assets.deploy
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

  ENV S3_SCHEME
  ENV S3_HOST
  ENV S3_PORT
  ENV DATABASE_URL
  ENV SECRET_KEY_BASE
  ENV LOOM_TOKENS_SECRET_KEY
  ENV AWS_ACCESS_KEY_ID
  ENV AWS_SECRET_ACCESS_KEY

  ENV OTEL_SERVICE_NAME=loom
  ENV MIX_ENV=prod

  CMD /app/rel/loom/bin/server

  SAVE IMAGE --push registry.digitalocean.com/cosmicrose-loom/loom:latest
