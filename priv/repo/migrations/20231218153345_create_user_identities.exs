defmodule Dakka.Repo.Migrations.CreateUserIdentities do
  use Ecto.Migration

  def change do
    create table(:users_identities) do
      add :provider, :string, null: false
      add :provider_id, :varchar, null: false
      add :provider_token, :varchar, null: false
      add :provider_meta, :map, default: "{}", null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create index(:users_identities, [:provider, :provider_id])
    create unique_index(:users_identities, [:user_id, :provider])
  end
end
