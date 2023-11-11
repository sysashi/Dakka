defmodule DakkaWeb.AnnouncementLive do
  use DakkaWeb, :live_view

  alias Dakka.Announcements
  alias Dakka.Announcements.Announcement

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Announcements
      <:actions>
        <.link patch={~p"/dashboard/announcements/new"}>
          <.button>New Announcement</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="announcements"
      rows={@streams.announcements}
      row_click={
        fn {_id, announcement} -> JS.navigate(~p"/dashboard/announcements/#{announcement}") end
      }
    >
      <:col :let={{_id, announcement}} label="Title"><%= announcement.title %></:col>
      <:col :let={{_id, announcement}} label="Body"><%= announcement.body %></:col>
      <:col :let={{_id, announcement}} label="Active"><%= announcement.active %></:col>
      <:col :let={{_id, announcement}} label="Expires at"><%= announcement.expires_at %></:col>
      <:col :let={{_id, announcement}} label="Kind"><%= announcement.kind %></:col>
      <:action :let={{_id, announcement}}>
        <div class="sr-only">
          <.link navigate={~p"/dashboard/announcements/#{announcement}"}>Show</.link>
        </div>
        <.link patch={~p"/dashboard/announcements/#{announcement}/edit"}>Edit</.link>
      </:action>
      <:action :let={{id, announcement}}>
        <.link
          phx-click={JS.push("delete", value: %{id: announcement.id}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
      <:action :let={{_id, announcement}}>
        <%= if announcement.active do %>
          <.link
            phx-click={JS.push("deactivate", value: %{id: announcement.id})}
            data-confirm="Are you sure?"
          >
            Deactivate
          </.link>
        <% else %>
          <.link
            phx-click={JS.push("activate", value: %{id: announcement.id})}
            data-confirm="Are you sure?"
          >
            Activate
          </.link>
        <% end %>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="announcement-modal"
      show
      on_cancel={JS.patch(~p"/dashboard/announcements")}
    >
      <.live_component
        module={DakkaWeb.AnnouncementLive.FormComponent}
        id={@announcement.id || :new}
        title={@page_title}
        action={@live_action}
        announcement={@announcement}
        patch={~p"/dashboard/announcements"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :announcements, Announcements.list_announcements())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Announcement")
    |> assign(:announcement, Announcements.get_announcement!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Announcement")
    |> assign(:announcement, %Announcement{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Announcements")
    |> assign(:announcement, nil)
  end

  @impl true
  def handle_info({DakkaWeb.AnnouncementLive.FormComponent, {:created, announcement}}, socket) do
    {:noreply, stream_insert(socket, :announcements, announcement, at: 0)}
  end

  def handle_info({DakkaWeb.AnnouncementLive.FormComponent, {:updated, announcement}}, socket) do
    {:noreply, stream_insert(socket, :announcements, announcement)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    announcement = Announcements.get_announcement!(id)
    {:ok, _} = Announcements.delete_announcement(announcement)

    {:noreply, stream_delete(socket, :announcements, announcement)}
  end

  def handle_event("activate", %{"id" => id}, socket) do
    announcement = Announcements.get_announcement!(id)

    case Announcements.activate_announcement(announcement) do
      {:ok, announcement} ->
        {:noreply, stream_insert(socket, :announcements, announcement)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    announcement = Announcements.get_announcement!(id)

    case Announcements.deactivate_announcement(announcement) do
      {:ok, announcement} ->
        {:noreply, stream_insert(socket, :announcements, announcement)}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
