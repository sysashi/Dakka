defmodule Dakka.Announcements.Announcement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "announcements" do
    field :title, :string
    field :body, :string
    field :kind, Ecto.Enum, values: [:info, :warning, :error], default: :info
    field :active, :boolean, default: false
    field :expires_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(announcement, attrs \\ %{}) do
    announcement
    |> cast(attrs, [:title, :body, :kind, :expires_at])
    |> validate_required([:body, :kind])
  end

  def set_active(announcement, flag) do
    change(announcement, %{active: flag})
  end
end
