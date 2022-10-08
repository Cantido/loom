defmodule Loom.Repo.Migrations.ReplaceAccountsWithTeams do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      remove :account_id
      add :team_id, references(:teams, on_delete: :delete_all, on_update: :update_all), null: false
    end

    alter table(:sources) do
      remove :account_id
      add :team_id, references(:teams, on_delete: :delete_all, on_update: :update_all), null: false
    end

    alter table(:webhooks) do
      remove :account_id
      add :team_id, references(:teams, on_delete: :delete_all, on_update: :update_all), null: false
    end

    drop table(:users_accounts)

    drop table(:accounts)
  end
end
