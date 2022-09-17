defmodule Loom.Repo.Migrations.AddAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      # no fields, yet
    end

    create table(:tokens) do
      add :account_id, references(:accounts, on_delete: :delete_all, on_update: :update_all), null: false
      add :username, :string, null: false
      add :password_hash, :string, null: false
    end

    create unique_index(:tokens, [:username])

    create table(:sources) do
      add :account_id, references(:accounts, on_delete: :delete_all, on_update: :update_all), null: false
      add :source, :string, null: false
    end

    create unique_index(:sources, [:source])

    alter table(:events) do
      remove :source, :string, null: false
      add :source_id, references(:sources, on_delete: :delete_all, on_update: :update_all), null: false
    end

    create unique_index(:events, [:source_id, :id])

    alter table(:counters) do
      remove :source, :string
      add :source_id, references(:sources, on_delete: :delete_all, on_update: :update_all), null: false, primary_key: true
    end
  end
end
