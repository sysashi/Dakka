defmodule Dakka.Repo.Migrations.CreateUserGameItems do
  use Ecto.Migration

  def change do
    # TODO timestamps
    create table(:users_game_items) do
      add :position, :integer
      add :quantity, :integer, default: 1, null: false
      add :item_base_id, references(:game_item_bases, on_delete: :restrict), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create table(:users_game_items_mods) do
      add :mod_type, :varchar, null: false
      add :value, :integer

      add :user_game_item_id, references(:users_game_items, on_delete: :delete_all), null: false
      add :item_mod_id, references(:game_item_mods, on_delete: :delete_all), null: false
    end

    create index(:users_game_items_mods, [:item_mod_id, :value])
    create index(:users_game_items_mods, [:item_mod_id, :mod_type, :value])

    create unique_index(:users_game_items_mods, [:mod_type, :user_game_item_id, :item_mod_id],
             name: :unique_user_game_item_mod_per_type
           )
  end
end
