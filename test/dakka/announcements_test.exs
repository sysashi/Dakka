defmodule Dakka.AnnouncementsTest do
  use Dakka.DataCase

  alias Dakka.Announcements

  describe "announcements" do
    alias Dakka.Announcements.Announcement

    import Dakka.AnnouncementsFixtures

    @invalid_attrs %{body: nil, kind: nil}

    test "list_announcements/0 returns all announcements" do
      announcement = announcement_fixture()
      assert Announcements.list_announcements() == [announcement]
    end

    test "get_announcement!/1 returns the announcement with given id" do
      announcement = announcement_fixture()
      assert Announcements.get_announcement!(announcement.id) == announcement
    end

    test "create_announcement/1 with valid data creates a announcement" do
      valid_attrs = %{
        title: "some title",
        body: "some body",
        kind: :warning,
        expires_at: ~U[2023-11-10 13:48:00.000000Z]
      }

      assert {:ok, %Announcement{} = announcement} =
               Announcements.create_announcement(valid_attrs)

      assert announcement.title == "some title"
      assert announcement.body == "some body"
      assert announcement.kind == :warning
      assert announcement.expires_at == ~U[2023-11-10 13:48:00.000000Z]
    end

    test "create_announcement/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Announcements.create_announcement(@invalid_attrs)
    end

    test "update_announcement/2 with valid data updates the announcement" do
      announcement = announcement_fixture()

      update_attrs = %{
        title: "some updated title",
        body: "some updated body",
        kind: :error,
        expires_at: ~U[2023-11-11 13:48:00.000000Z]
      }

      assert {:ok, %Announcement{} = announcement} =
               Announcements.update_announcement(announcement, update_attrs)

      assert announcement.title == "some updated title"
      assert announcement.body == "some updated body"
      assert announcement.kind == :error
      assert announcement.expires_at == ~U[2023-11-11 13:48:00.000000Z]
    end

    test "update_announcement/2 with invalid data returns error changeset" do
      announcement = announcement_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Announcements.update_announcement(announcement, @invalid_attrs)

      assert announcement == Announcements.get_announcement!(announcement.id)
    end

    test "delete_announcement/1 deletes the announcement" do
      announcement = announcement_fixture()
      assert {:ok, %Announcement{}} = Announcements.delete_announcement(announcement)
      assert_raise Ecto.NoResultsError, fn -> Announcements.get_announcement!(announcement.id) end
    end

    test "change_announcement/1 returns a announcement changeset" do
      announcement = announcement_fixture()
      assert %Ecto.Changeset{} = Announcements.change_announcement(announcement)
    end
  end
end
