# Loom

![Elixir CI](https://github.com/Cantido/loom/workflows/Elixir%20CI/badge.svg)

An event store database that speaks the [CloudEvents specification](https://github.com/cloudevents/spec).

## Installation

Loom is deployed as a Docker container, and requires only a Postgres database URL and a secret key for cookie signing.

```sh
docker run -e DATABASE_URL=ecto://username:password@host/db -e SECRET_KEY_BASE=$(mix phx.gen.secret) -p 4000:4000 ghcr.io/cantido/loom
```

## Usage

To use Loom, you must first create an account and an API token via the web interface.
Then you can make API calls using basic auth.
See the OpenAPI spec at `postman/schemas/openapi.yaml` for API documentation.

## Maintainer

This project was developed by [Rosa Richter](https://github.com/Cantido).
You can get in touch with her on [Keybase.io](https://keybase.io/cantido).

## Contributing

Questions and pull requests are more than welcome.
I follow Elixir's tenet of bad documentation being a bug,
so if anything is unclear, please [file an issue](https://github.com/Cantido/loom/issues/new)!
Ideally, my answer to your question will be in an update to the docs.

## License

MIT License

Copyright 2022 Rosa Richter

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
