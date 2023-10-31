defmodule DakkaWeb.CharactersLive do
  use DakkaWeb, :live_view

  alias Dakka.Accounts
  alias Dakka.Accounts.UserGameCharacter

  def render(assigns) do
    ~H"""
    <article>
      <section class="text-right">
        <.link
          patch={~p"/characters/add"}
          class={[button_style(:primary), button_size(:md), "border"]}
        >
          Add Character
        </.link>
      </section>
      <.table id="characters" rows={@streams.characters}>
        <:col :let={{_, char}} label="Name"><%= char.name %></:col>
        <:col :let={{_, char}} label="Class"><%= char.class %></:col>
        <:col :let={{_, char}} label="Created"><%= format_timestamp(char.inserted_at) %></:col>
        <:action :let={{_, char}}>
          <.link
            patch={~p"/characters/edit/#{char.id}"}
            class={[button_style(:primary), button_size(:sm), "border"]}
          >
            Edit
          </.link>
        </:action>
        <:action :let={{_, char}}>
          <span
            class="bg-red-800 p-1 border border-red-900 hover:border-red-600 hover:bg-red-700 hover:cursor-pointer group transition-colors duration-150"
            phx-click={JS.push("delete-character", value: %{id: char.id})}
            data-confirm={"Delete #{char.name}?"}
          >
            <.icon name="hero-trash" class="w-5 h-5 text-red-200 mb-0.5 group-hover:text-red-100" />
          </span>
        </:action>
      </.table>
    </article>

    <.modal
      :if={@live_action in [:new_character, :edit_character]}
      show
      id="character-modal"
      on_cancel={JS.patch(~p"/characters")}
    >
      <.live_component
        scope={@scope}
        module={DakkaWeb.GameLive.CharacterFormComponent}
        id={@character.id || :new}
        title={@page_title}
        action={@live_action}
        patch={~p"/characters"}
        return_to={@return_to}
        character={@character}
      />
    </.modal>
    """
  end

  def mount(_params, _session, socket) do
    characters = Accounts.list_user_characters(socket.assigns.scope)

    socket =
      socket
      |> stream(:characters, characters)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:return_to, params["return_to"])
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  def handle_event("delete-character", %{"id" => id}, socket) do
    case Accounts.delete_user_character(socket.assigns.scope, id) do
      {:ok, char} ->
        socket =
          socket
          |> stream_delete(:characters, char)
          |> put_flash(:info, "Character has been deleted")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_info({:new_character, char}, socket) do
    socket =
      socket
      |> stream_insert(:characters, char, at: 0)
      |> push_event("highlight", %{id: "characters-#{char.id}"})

    {:noreply, socket}
  end

  def handle_info({:edit_character, char}, socket) do
    socket =
      socket
      |> stream_insert(:characters, char)
      |> push_event("highlight", %{id: "characters-#{char.id}"})

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Characters")
  end

  defp apply_action(socket, :new_character, _params) do
    socket
    |> assign(:page_title, "Add Character")
    |> assign(:character, %UserGameCharacter{})
  end

  defp apply_action(socket, :edit_character, %{"id" => id}) do
    %{scope: scope} = socket.assigns

    socket
    |> assign(:page_title, "Edit Character")
    |> assign(:character, Accounts.get_user_character!(scope, id))
  end

  defp format_timestamp(ts) do
    ts
    |> DateTime.from_naive!("Etc/UTC")
    |> Dakka.Cldr.DateTime.to_string!()
  end
end
