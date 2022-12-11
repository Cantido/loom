defmodule Loom.Repo.Migrations.AddTimestampsToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      timestamps()
    end

    alter table(:sources) do
      timestamps()
    end

    alter table(:counters) do
      timestamps()
    end
  end
end
