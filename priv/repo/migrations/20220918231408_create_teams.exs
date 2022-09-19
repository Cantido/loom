defmodule Loom.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :name, :string

      timestamps()
    end

    create table(:roles, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :team_id, references(:teams, on_delete: :delete_all), primary_key: true
      add :role, :string, null: false

      timestamps()
    end
  end
end
