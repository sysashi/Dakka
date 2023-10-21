defmodule DakkaWeb.ListingFormComponent do
  use DakkaWeb, :live_component

  alias Dakka.Market

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-xs min-w-[400px]">
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <.input type="checkbox" field={@form[:relist]} class!="hidden" />

        <div class="flex gap-4">
          <.input type="number" field={@form[:price_gold]} label="Gold" />
          <.input type="number" field={@form[:price_golden_keys]} label="Golden Keys" />
        </div>

        <.input type="checkbox" field={@form[:open_for_offers]} label="Open for Offers" />

        <div class="flex justify-between items-center">
          <.button phx-disable-with="Saving...">
            Save Listing
          </.button>

          <.button
            :if={@id != :new && !@listing.relist}
            class="bg-blue-500"
            type="button"
            style={:extra}
            phx-click="mark-sold"
            phx-target={@myself}
          >
            Mark as Sold
          </.button>

          <span
            :if={@id != :new && !@listing.relist}
            phx-target={@myself}
            class="text-red-300 underline underline-offset-4 italic cursor-pointer"
            phx-click="delete"
          >
            Delete
          </span>
        </div>
      </.form>

      <div class="text-gray-100 bg-sky-600/30  mt-4 p-2 text-sm">
        <.icon name="hero-information-circle-mini" class="mb-[1px] h-4 w-4" /> Notice
        <ul class="list-disc list-inside mt-2 ml-2">
          <li><b>Changing price</b> of the item</li>
          <li>Marking listing as <b> sold </b></li>
          <li><b>Deleting</b> listing</li>
        </ul>
        <p class="mt-2 ml-2">
          Will decline all active offers for this item
        </p>
      </div>
    </div>
    """
  end

  # defp status_colors(:active), do: "bg-lime-900 text-gray-300 border-lime-700 rounded-md"
  # defp status_colors(:expired), do: "bg-amber-300 text-gray-600 border-amber-400"
  # defp status_colors(:sold), do: "bg-red-300 text-gray-600 border-red-400"

  @impl true
  def update(%{listing: listing} = assigns, socket) do
    changeset = Market.change_listing(listing)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"listing" => params}, socket) do
    listing = socket.assigns.listing

    changeset =
      listing
      |> Market.change_listing(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"listing" => params}, socket) do
    save_listing(socket, socket.assigns.action, params)
  end

  def handle_event("mark-sold", _, socket) do
    listing = socket.assigns.listing

    case Market.mark_listing_sold(listing) do
      {:ok, _listing} ->
        socket =
          socket
          |> put_flash(:info, "Item was marked sold")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("delete", _, socket) do
    listing = socket.assigns.listing

    case Market.delete_listing(listing) do
      {:ok, _listing} ->
        socket =
          socket
          |> put_flash(:info, "Item listing deleted")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_listing(socket, :new_listing, params) do
    listing = socket.assigns.listing

    case Market.create_listing(listing, params) do
      {:ok, _listing} ->
        socket =
          socket
          |> put_flash(:info, "Item is listed on the Market")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_listing(socket, :edit_listing, params) do
    listing = socket.assigns.listing

    case Market.edit_listing(listing, params) do
      {:ok, _listing} ->
        socket =
          socket
          |> put_flash(:info, "Item Listing was updated")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
