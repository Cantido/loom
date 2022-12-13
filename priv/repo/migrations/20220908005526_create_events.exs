defmodule Loom.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table("events", primary_key: false) do
      # No specversion because all events should be normalized to the latest CE version
      add :id, :string, primary_key: true
      add :source, :string, primary_key: true
      add :type, :string, null: false
      add :data, :binary
      add :dataschema, :string
      add :datacontenttype, :string
      add :time, :utc_datetime_usec
      add :subject, :string
      add :extensions, {:map, :string}
    end

    create index("events", [:type])
  end
end
