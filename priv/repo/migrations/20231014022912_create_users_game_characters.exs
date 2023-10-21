defmodule Dndah.Repo.Migrations.CreateUsersGameCharacters do
  use Ecto.Migration

  def change do
    create table(:users_game_characters) do
      add :name, :varchar, null: false
      add :last_trade_at, :naive_datetime
      add :removal_scheduled_at, :naive_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:users_game_characters, [:user_id])
    create unique_index(:users_game_characters, [:name])
  end
end
