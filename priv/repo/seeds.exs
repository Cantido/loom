# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Loom.Repo.insert!(%Loom.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

{:ok, user} = Loom.Accounts.register_user(%{email: "example@example.com", password: "123456789012"})

{:ok, team} = Loom.Accounts.create_team(%{name: "Example Team"}, user)

creds = %{
  username: "AYR4v3FeeE-Lo5h9SxVHRw",
  password: "HHpPDlwJq8EeUe5wdzH-urQYSEzpIKJyT2exe6lnQvc"
}

{:ok, token} = Loom.Accounts.create_token(team, creds)

{:ok, source} = Loom.Store.create_source(team, "test-source")

IO.puts("Seeded API credentials: #{creds.username}:#{creds.password}")

IO.puts("Seeded event source: #{source.source}")



