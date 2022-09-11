defmodule Loom.Cache do
  @moduledoc """
  A `Nebulex.Cache` for Loom.
  """

  use Nebulex.Cache,
    otp_app: :loom,
    adapter: Nebulex.Adapters.Local
end
