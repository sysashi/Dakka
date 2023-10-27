defmodule DakkaWeb.UserSettingsFormComponent do
  use DakkaWeb, :live_component

  alias Dakka.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <article class="text-zinc-100 w-60">
      <h2 class="text-2xl mb-2">App Settings</h2>
      <.form for={@form} phx-change="update" phx-target={@myself} class="space-y-4">
        <section>
          <h3 class="text-xl mb-1">Display</h3>
          <.inputs_for :let={form} field={@form[:display]}>
            <.input type="checkbox" field={form[:show_item_icon]} label="Item Icon" />
            <.input type="checkbox" field={form[:show_item_properties]} label="Item Properties" />
            <.input type="checkbox" field={form[:show_item_flavor_text]} label="Item Flavor Text" />
          </.inputs_for>
        </section>

        <section>
          <h3 class="text-xl mb-1">Browser Notifications</h3>
          <.inputs_for :let={form} field={@form[:notifications]}>
            <.input type="hidden" field={form[:action]} hidden />
            <.input type="checkbox" field={form[:enabled]} label={action_label(form[:action].value)} />
          </.inputs_for>
          <span
            class={[
              "text-white text-xs py-1 px-1 inline-block border mt-2 cursor-pointer",
              "[&.notif-enabled]:bg-green-600 [&.notif-enabled]:border-green-500",
              "[&.notif-disabled]:bg-blue-600 [&.notif-disabled]:border-blue-500"
            ]}
            phx-click={JS.dispatch("enable-browser-notifications")}
            id="browser-notifications"
            phx-hook="BrowserNotifications"
          >
            Enable browser notifications
          </span>
        </section>
      </.form>
    </article>
    """
  end

  defp action_label("offer_created"), do: "Offer Created"
  defp action_label("offer_accepted"), do: "Offer Accepted"
  defp action_label("offer_declined"), do: "Offer Declined"
  defp action_label("offer_cancelled"), do: "Offer Cancelled"
  defp action_label(action), do: action

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{scope: scope} = assigns, socket) do
    changeset =
      if scope.current_user && scope.current_user.settings do
        Accounts.change_user_settings(scope)
      else
        Accounts.UserSettings.change_default_settings()
      end

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    case Accounts.update_user_settings(socket.assigns.scope, params) do
      {:ok, user} ->
        {:noreply, assign(socket, :scope, Dakka.Scope.for_user(user))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Ecto.Changeset.get_embed(changeset, :settings))}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :settings))
  end
end
