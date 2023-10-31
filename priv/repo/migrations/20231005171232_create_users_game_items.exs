defmodule Dakka.Repo.Migrations.CreateUserGameItems do
  use Ecto.Migration

  def change do
    create table(:users_game_items) do
      add :position, :integer
      add :quantity, :integer, default: 1, null: false
      add :item_base_id, references(:game_item_bases, on_delete: :restrict), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :deleted_at, :naive_datetime_usec

      timestamps()
    end

    create index(:users_game_items, [:user_id])
    create index(:users_game_items, [:position])
    create index(:users_game_items, [:inserted_at])
    create index(:users_game_items, [:item_base_id])

    create table(:users_game_items_mods) do
      add :mod_type, :varchar, null: false
      add :value, :integer

      add :user_game_item_id, references(:users_game_items, on_delete: :delete_all), null: false
      add :item_mod_id, references(:game_item_mods, on_delete: :delete_all), null: false
    end

    create index(:users_game_items_mods, [:item_mod_id])
    create index(:users_game_items_mods, [:user_game_item_id])
    create index(:users_game_items_mods, [:mod_type, :value])

    create unique_index(:users_game_items_mods, [:mod_type, :user_game_item_id, :item_mod_id],
             name: :unique_user_game_item_mod_per_type
           )
  end
end
