defmodule Loom.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :types, {:array, :string}
      add :config, {:map, :string}
      add :filters, {:map, :string}
      add :sink, :string, null: false
      add :sink_credential, {:map, :string}
      add :source_id, references(:sources, on_delete: :delete_all, on_update: :update_all), null: false
      add :protocol, :string, null: false
      add :protocolsettings, {:map, :string}

      timestamps()
    end
  end
end
