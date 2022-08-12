defmodule Loom.Cache do
  use Nebulex.Cache,
    otp_app: :loom,
    adapter: Nebulex.Adapters.Local
end
