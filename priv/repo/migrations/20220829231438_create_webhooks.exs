defmodule Loom.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create table(:webhooks) do
      add :url, :string, null: false
      add :token, :string, null: false
      add :type, :string, null: false

      timestamps()
    end
  end
end
