defmodule Dakka.Repo.Migrations.AddQuickSellToMarketListings do
  use Ecto.Migration

  def change do
    alter table(:market_listings) do
      add :quick_sell, :boolean, default: false, null: false
      add :user_game_character_id, references(:users_game_characters, on_delete: :nilify_all)
    end

    create constraint(
             :market_listings,
             :market_listings_require_character_for_quick_sell,
             check: "quick_sell is false or (quick_sell and user_game_character_id is not null)"
           )
  end
end
