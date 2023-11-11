defmodule DakkaWeb.AnnouncementLiveTest do
  use DakkaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Dakka.AnnouncementsFixtures

  @create_attrs %{
    title: "some title",
    body: "some body",
    kind: :info
  }
  @update_attrs %{
    title: "some updated title",
    body: "some updated body",
    kind: :warning
  }
  @invalid_attrs %{body: nil}

  defp create_announcement(_) do
    announcement = announcement_fixture()
    %{announcement: announcement}
  end

  defp login_as_admin(%{conn: conn}) do
    admin = Dakka.AccountsFixtures.user_fixture(%{username: "testadmin"})
    %{conn: log_in_user(conn, admin)}
  end

  describe "Index" do
    setup [:create_announcement, :login_as_admin]

    test "lists all announcements", %{conn: conn, announcement: announcement} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/announcements")

      assert html =~ "Listing Announcements"
      assert html =~ announcement.title
    end

    test "saves new announcement", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/announcements")

      assert index_live |> element("a", "New Announcement") |> render_click() =~
               "New Announcement"

      assert_patch(index_live, ~p"/dashboard/announcements/new")

      assert index_live
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#announcement-form", announcement: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/dashboard/announcements")

      html = render(index_live)
      assert html =~ "Announcement created successfully"
      assert html =~ "some title"
    end

    test "updates announcement in listing", %{conn: conn, announcement: announcement} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/announcements")

      assert index_live
             |> element("#announcements-#{announcement.id} a", "Edit")
             |> render_click() =~
               "Edit Announcement"

      assert_patch(index_live, ~p"/dashboard/announcements/#{announcement}/edit")

      assert index_live
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#announcement-form", announcement: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/dashboard/announcements")

      html = render(index_live)
      assert html =~ "Announcement updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes announcement in listing", %{conn: conn, announcement: announcement} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/announcements")

      assert index_live
             |> element("#announcements-#{announcement.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#announcements-#{announcement.id}")
    end
  end

  describe "Show" do
    setup [:create_announcement, :login_as_admin]

    test "displays announcement", %{conn: conn, announcement: announcement} do
      {:ok, _show_live, html} = live(conn, ~p"/dashboard/announcements/#{announcement}")

      assert html =~ "Show Announcement"
      assert html =~ announcement.title
    end

    test "updates announcement within modal", %{conn: conn, announcement: announcement} do
      {:ok, show_live, _html} = live(conn, ~p"/dashboard/announcements/#{announcement}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Announcement"

      assert_patch(show_live, ~p"/dashboard/announcements/#{announcement}/show/edit")

      assert show_live
             |> form("#announcement-form", announcement: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#announcement-form", announcement: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/dashboard/announcements/#{announcement}")

      html = render(show_live)
      assert html =~ "Announcement updated successfully"
      assert html =~ "some updated title"
    end
  end
end
