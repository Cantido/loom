defmodule Loom.Repo.Migrations.AssociateTokensWithTeams do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add :team, references(:teams, on_delete: :delete_all), null: false
    end
  end
end
