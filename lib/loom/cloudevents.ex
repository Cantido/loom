defmodule Loom.Cloudevents do
  @moduledoc """
  Functions for working with `Cloudevents` structs.
  """

  def put_new_time(cloudevent, time) do
    if is_nil(cloudevent.time) do
      struct(cloudevent, time: time)
    else
      cloudevent
    end
  end

  @doc """
  Puts an extension value in the Cloudevent.

  Overwrites existing values at that key.
  """
  def put_extension(cloudevent, key, value) do
    extensions = Map.put(cloudevent.extensions, key, value)

    struct(cloudevent, extensions: extensions)
  end

  @doc """
  Puts an extension value in the Cloudevent.

  Does nothing if the key already exists.
  """
  def put_new_extension(cloudevent, key, value) do
    extensions = Map.put_new(cloudevent.extensions, key, value)

    struct(cloudevent, extensions: extensions)
  end
end
