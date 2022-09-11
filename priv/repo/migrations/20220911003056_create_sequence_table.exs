defmodule Loom.Repo.Migrations.CreateSequenceTable do
  use Ecto.Migration

  def change do
    create table(:counters, primary_key: false) do
      add :source, :string, primary_key: true
      add :value, :integer, default: 0, null: false
    end
  end
end
