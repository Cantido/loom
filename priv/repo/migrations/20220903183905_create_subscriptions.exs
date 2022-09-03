defmodule Loom.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :source, :string
      add :types, {:array, :string}
      add :sink, :string, null: false
      add :sink_credentials, {:map, :string}
      add :protocol, :string, null: false
      add :protocol_settings, {:map, :string}
      add :filters, {:array, :map}
      add :config, :map

      timestamps()
    end
  end
end
