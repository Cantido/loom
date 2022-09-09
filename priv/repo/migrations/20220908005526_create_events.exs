defmodule Loom.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table("events", primary_key: false) do
      # No specversion because all events should be normalized to the latest CE version
      add :id, :string, null: false
      add :source, :string, null: false
      add :type, :string, null: false
      add :data, :binary
      add :dataschema, :string
      add :datacontenttype, :string
      add :time, :utc_datetime_usec
      add :extensions, {:map, :string}
    end

    create unique_index("events", [:source, :id])
    create index("events", [:type])
  end
end
