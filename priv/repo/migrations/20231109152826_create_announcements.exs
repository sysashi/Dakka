defmodule Dakka.Repo.Migrations.CreateAnnouncements do
  use Ecto.Migration

  def change do
    create table(:announcements) do
      add :title, :varchar
      add :body, :text, null: false
      add :kind, :string, null: false, default: "info"
      add :active, :boolean, default: false, null: false
      add :expires_at, :utc_datetime_usec

      timestamps()
    end
  end
end
