defmodule Loom.Event do
  @enforce_keys [:type]
  defstruct [:type, extensions: %{}]
end
