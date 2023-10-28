defmodule DakkaWeb.MarketLive.OfferFormComponent do
  use DakkaWeb, :live_component

  alias Dakka.Market

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md">
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <div class="flex gap-4">
          <.input type="number" field={@form[:offer_gold_amount]} label="Gold" />
          <.input type="number" field={@form[:offer_golden_keys_amount]} label="Golden Keys" />
        </div>

        <div phx-feedback-for={@form[:listing].name}>
          <.error :for={msg <- Enum.map(@form[:listing].errors, &translate_error(&1))}>
            <%= msg %>
          </.error>
        </div>

        <.button phx-disable-with="Saving...">
          Save
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{offer: offer} = assigns, socket) do
    changeset = Market.change_offer(offer)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"offer" => params}, socket) do
    offer = socket.assigns.offer

    changeset =
      offer
      |> Market.change_offer(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"offer" => params}, socket) do
    save_listing(socket, socket.assigns.action, params)
  end

  defp save_listing(socket, :new_offer, params) do
    listing_id = socket.assigns.listing_id

    case Market.create_offer(socket.assigns.scope, listing_id, params) do
      {:ok, _offer} ->
        socket =
          socket
          |> put_flash(:info, "Offer Created")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "#{inspect(reason)}")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :offer))
  end
end
