defmodule Dakka.Repo.Migrations.CreateUsersNotifications do
  use Ecto.Migration

  def change do
    create table(:users_notifications) do
      add :object, :varchar, null: false
      add :action, :varchar, null: false
      add :actor_id, references(:users, on_delete: :nilify_all)

      add :meta, :jsonb, default: "{}", null: false
      add :read_at, :naive_datetime

      # object refs
      add :listing_id, references(:market_listings, on_delete: :delete_all)
      add :offer_id, references(:market_listings_offers, on_delete: :delete_all)

      # target
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(:users_notifications, [:user_id])
    create index(:users_notifications, [:user_id, :action])
    create index(:users_notifications, [:user_id, :read_at])
  end
end
