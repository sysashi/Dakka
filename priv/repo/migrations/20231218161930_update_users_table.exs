defmodule Dakka.Repo.Migrations.UpdateUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar_url, :varchar
      modify :hashed_password, :string, null: true, from: {:string, null: false}
    end
  end
end
