# Loom

A filesystem-based event store.

Events are JSON-encoded according to the CloudEvents spec and stored at `events/<event-source>/<event-id>.json`.
When an event is appended to a stream, a symlink is created at `streams/<stream-id>/<revsion-number>.json`.

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
