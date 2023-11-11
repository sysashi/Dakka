defmodule Dakka.Announcements do
  @moduledoc """
  App wide Announcements
  """

  import Ecto.Query

  alias Dakka.Repo
  alias Dakka.Announcements.Announcement

  alias Dakka.Announcements.Events.{
    AnnouncementActivated,
    AnnouncementDeactivated,
    AnnouncementUpdated
  }

  @pubsub Dakka.PubSub

  def subscribe() do
    Phoenix.PubSub.subscribe(@pubsub, topic())
  end

  def broadcast(event) do
    Phoenix.PubSub.broadcast(@pubsub, topic(), {__MODULE__, event})
  end

  defp topic(), do: "announcements"

  def list_active_announcements(opts \\ []) do
    exclude = Keyword.get(opts, :exclude, [])

    Announcement
    |> where(active: true)
    |> where([a], a.id not in ^exclude)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def list_announcements() do
    Announcement
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def get_announcement!(id), do: Repo.get!(Announcement, id)

  def create_announcement(attrs) do
    %Announcement{}
    |> Announcement.changeset(attrs)
    |> Repo.insert()
  end

  def update_announcement(%Announcement{} = announcement, attrs) do
    changeset = Announcement.changeset(announcement, attrs)

    with {:ok, announcement} <- Repo.update(changeset) do
      if announcement.active do
        broadcast(%AnnouncementUpdated{announcement: announcement})
      end

      {:ok, announcement}
    end
  end

  def activate_announcement(%Announcement{} = announcement) do
    changeset = Announcement.set_active(announcement, true)

    with {:ok, announcement} <- Repo.update(changeset) do
      broadcast(%AnnouncementActivated{announcement: announcement})
      {:ok, announcement}
    end
  end

  def deactivate_announcement(%Announcement{} = announcement) do
    changeset = Announcement.set_active(announcement, false)

    with {:ok, announcement} <- Repo.update(changeset) do
      broadcast(%AnnouncementDeactivated{announcement: announcement})
      {:ok, announcement}
    end
  end

  def delete_announcement(%Announcement{} = announcement) do
    with {:ok, _} <- Repo.delete(announcement) do
      broadcast(%AnnouncementDeactivated{announcement: announcement})
      {:ok, announcement}
    end
  end

  def change_announcement(%Announcement{} = announcement, attrs \\ %{}) do
    Announcement.changeset(announcement, attrs)
  end
end
