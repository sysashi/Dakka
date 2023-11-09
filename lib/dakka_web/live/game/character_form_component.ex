defmodule DakkaWeb.GameLive.CharacterFormComponent do
  use DakkaWeb, :live_component

  alias Dakka.Accounts
  alias Dakka.Accounts.UserGameCharacter

  @impl true
  def render(assigns) do
    ~H"""
    <article>
      <.simple_form
        for={@form}
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
        id={"character-form-#{@id}"}
      >
        <.input type="text" field={@form[:name]} label="Name" />
        <.input
          type="select"
          field={@form[:class]}
          label="Class (optional)"
          options={UserGameCharacter.class_options()}
          prompt="(empty)"
        />
        <.button type="submit">Save</.button>
      </.simple_form>
    </article>
    """
  end

  @impl true
  def update(%{character: char} = assigns, socket) do
    changeset = Accounts.change_user_character(char)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"character" => params}, socket) do
    char = socket.assigns.character

    changeset =
      char
      |> Accounts.change_user_character(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"character" => params}, socket) do
    save_character(socket, socket.assigns.action, params)
  end

  defp save_character(socket, :new_character, params) do
    case Accounts.create_user_character(socket.assigns.scope, params) do
      {:ok, character} ->
        socket =
          socket
          |> put_flash(:info, "Character Created")
          |> return_to_or_patch()

        socket.assigns.on_character_create.(character)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_character(socket, :edit_character, params) do
    case Accounts.update_user_character(socket.assigns.scope, socket.assigns.character, params) do
      {:ok, character} ->
        socket =
          socket
          |> put_flash(:info, "Character Updated")
          |> push_patch(to: socket.assigns.patch)

        socket.assigns.on_character_update.(character)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :character))
  end

  defp return_to_or_patch(socket) do
    if return_to = socket.assigns.return_to do
      push_navigate(socket, to: return_to)
    else
      push_patch(socket, to: socket.assigns.patch)
    end
  end
end
