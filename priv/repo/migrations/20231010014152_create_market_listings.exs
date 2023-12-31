defmodule Dakka.Repo.Migrations.CreateMarketListings do
  use Ecto.Migration

  def change do
    create table(:market_listings) do
      add :user_game_item_id, references(:users_game_items, on_delete: :delete_all), null: false
      add :price_gold, :integer
      add :price_golden_keys, :integer
      add :open_for_offers, :boolean, default: false, null: false
      add :status, :varchar, null: false, default: "active"
      add :deleted_at, :naive_datetime_usec

      timestamps()
    end

    create index(:market_listings, [:status])
    create index(:market_listings, [:price_gold])
    create index(:market_listings, [:price_golden_keys])
    create index(:market_listings, [:user_game_item_id])
    create index(:market_listings, [:inserted_at])

    create unique_index(:market_listings, [:user_game_item_id],
             where: "deleted_at is null",
             name: :market_listings_unique_active_item_listing_idx
           )

    create constraint(:market_listings, :valid_listing_statuses,
             check: ~s|status in ('active', 'sold', 'expired')|
           )

    create constraint(:market_listings, :positive_price,
             check: ~s|price_gold > 0 and price_golden_keys > 0|
           )

    create constraint(:market_listings, :price_set_or_open_for_offers,
             check: ~s|open_for_offers or num_nonnulls(price_gold, price_golden_keys) > 0|
           )

    create table(:market_listings_offers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :listing_id, references(:market_listings, on_delete: :delete_all), null: false
      add :offer_gold_amount, :integer
      add :offer_golden_keys_amount, :integer
      add :status, :varchar, null: false, default: "active"

      timestamps()
    end

    create index(:market_listings_offers, [:status])
    create index(:market_listings_offers, [:user_id])
    create index(:market_listings_offers, [:inserted_at])
    create index(:market_listings_offers, [:listing_id])

    create unique_index(:market_listings_offers, [:user_id, :listing_id],
             name: :market_listings_offers_one_active,
             where: "status = 'active'"
           )

    create unique_index(:market_listings_offers, [:user_id, :listing_id],
             name: :market_listings_offers_one_accepted,
             where: "status = 'accepted_by_seller'"
           )

    create constraint(:market_listings_offers, :valid_offer_statuses,
             check: ~s"""
               status in (
                 'active',
                 'accepted_by_seller',
                 'declined_by_seller',
                 'declined_listing_sold',
                 'declined_listing_expired',
                 'declined_listing_deleted',
                 'declined_listing_changed',
                 'cancelled_by_buyer',
                 'expired'
               )
             """
           )

    create constraint(:market_listings_offers, :offer_amount_set,
             check: ~s|num_nonnulls(offer_gold_amount, offer_golden_keys_amount) > 0|
           )

    create constraint(:market_listings_offers, :positive_offer_amount,
             check: ~s|offer_gold_amount > 0 and offer_golden_keys_amount > 0|
           )
  end
end
