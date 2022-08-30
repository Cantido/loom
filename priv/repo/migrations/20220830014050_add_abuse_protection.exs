defmodule Loom.Repo.Migrations.AddAbuseProtection do
  use Ecto.Migration

  def change do
    alter table("webhooks") do
      add :validated, :boolean, default: false, null: false
      add :allowed_rate, :integer, default: 0, null: false
    end
  end
end
