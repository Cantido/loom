defmodule LoomTest do
  use ExUnit.Case
  doctest Loom

  test "greets the world" do
    assert Loom.hello() == :world
  end
end
