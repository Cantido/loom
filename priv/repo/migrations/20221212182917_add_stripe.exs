defmodule Loom.Repo.Migrations.AddStripe do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :billing_user_id, references(:users, on_update: :update_all, on_delete: :nilify_all)
      add :stripe_subscription_item_id, :string
    end

    alter table(:users) do
      add :stripe_customer_id, :string
    end
  end
end
