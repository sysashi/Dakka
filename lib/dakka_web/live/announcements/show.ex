defmodule DakkaWeb.AnnouncementLive.Show do
  use DakkaWeb, :live_view

  alias Dakka.Announcements

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Announcement <%= @announcement.id %>
      <:subtitle>This is a announcement record from your database.</:subtitle>
      <:actions>
        <.link
          patch={~p"/dashboard/announcements/#{@announcement}/show/edit"}
          phx-click={JS.push_focus()}
        >
          <.button>Edit announcement</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <h4 class="text-lg text-zinc-200">Preview</h4>
      <.announcement
        id={@announcement.id}
        title={@announcement.title}
        kind={@announcement.kind}
        body={@announcement.body}
      />
    </div>

    <.list>
      <:item title="Title"><%= @announcement.title %></:item>
      <:item title="Body"><%= @announcement.body %></:item>
      <:item title="Active"><%= @announcement.active %></:item>
      <:item title="Expires at"><%= @announcement.expires_at %></:item>
      <:item title="Kind"><%= @announcement.kind %></:item>
    </.list>

    <.back navigate={~p"/dashboard/announcements"}>Back to announcements</.back>

    <.modal
      :if={@live_action == :edit}
      id="announcement-modal"
      show
      on_cancel={JS.patch(~p"/dashboard/announcements/#{@announcement}")}
    >
      <.live_component
        module={DakkaWeb.AnnouncementLive.FormComponent}
        id={@announcement.id}
        title={@page_title}
        action={@live_action}
        announcement={@announcement}
        patch={~p"/dashboard/announcements/#{@announcement}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:announcement, Announcements.get_announcement!(id))}
  end

  defp page_title(:show), do: "Show Announcement"
  defp page_title(:edit), do: "Edit Announcement"
end
