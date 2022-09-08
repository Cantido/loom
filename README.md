# Loom

An event store database.

Loom implements the [CloudEvents specification](https://github.com/cloudevents/spec) for maximum compatibility with modern event-based systems.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `loom` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:loom, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/loom>.

## Troubleshooting

If you start getting errors about running out of file descriptors, then your file descriptor limit is too low.
Use `unlimit` to change your limit.

```
ulimit -n 4096
```
