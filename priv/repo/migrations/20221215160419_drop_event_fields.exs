defmodule Loom.Repo.Migrations.DropEventFields do
  use Ecto.Migration

  def change do
    alter table(:events) do
      remove :data, :binary
    end
  end
end
