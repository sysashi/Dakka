defmodule DakkaWeb.AnnouncementLive.FormComponent do
  use DakkaWeb, :live_component

  alias Dakka.Announcements

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage announcement records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="announcement-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:body]} type="textarea" label="Body" />
        <.input field={@form[:kind]} type="select" label="Kind" options={~w(info warning error)} />
        <:actions>
          <.button phx-disable-with="Saving...">Save Announcement</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{announcement: announcement} = assigns, socket) do
    changeset = Announcements.change_announcement(announcement)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"announcement" => announcement_params}, socket) do
    changeset =
      socket.assigns.announcement
      |> Announcements.change_announcement(announcement_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"announcement" => announcement_params}, socket) do
    save_announcement(socket, socket.assigns.action, announcement_params)
  end

  defp save_announcement(socket, :edit, announcement_params) do
    case Announcements.update_announcement(socket.assigns.announcement, announcement_params) do
      {:ok, announcement} ->
        notify_parent({:updated, announcement})

        {:noreply,
         socket
         |> put_flash(:info, "Announcement updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_announcement(socket, :new, announcement_params) do
    case Announcements.create_announcement(announcement_params) do
      {:ok, announcement} ->
        notify_parent({:created, announcement})

        {:noreply,
         socket
         |> put_flash(:info, "Announcement created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
