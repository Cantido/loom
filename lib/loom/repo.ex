defmodule Loom.Repo do
  use Ecto.Repo,
    otp_app: :loom,
    adapter: Ecto.Adapters.Postgres
end
