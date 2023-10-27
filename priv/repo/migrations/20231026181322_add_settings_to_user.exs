defmodule Dakka.Repo.Migrations.AddSettingsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :settings, :jsonb
    end
  end
end
