defmodule DakkaWeb.InventoryLive do
  use DakkaWeb, :live_view

  import DakkaWeb.GameComponents

  alias Dakka.Inventory
  alias Dakka.Market

  alias Dakka.Market.Events.{
    ListingCreated,
    ListingDeleted,
    ListingExpired,
    ListingSold,
    ListingUpdated
  }

  alias Dakka.Inventory.Events.UserItemCreated

  def render(assigns) do
    ~H"""
    <div class="mb-4 border-b border-zinc-700 pb-4">
      <h3 class="text-center mb-2 text-2xl text-gray-500">Add new item</h3>
      <.live_component
        module={DakkaWeb.Inventory.AddItemLive}
        id="add-item"
        current_user={@current_user}
      />
    </div>
    <article class="flex text-white">
      <section
        id="user-items"
        class="grid grid-cols-1 px-10 sm:px-0 mx-auto sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-x-2 gap-y-4 auto-rows-max items-baseline"
        phx-update="stream"
      >
        <%= for {id, item} <- @streams.items do %>
          <div class="flex flex-col" id={id}>
            <.item_card item={item} show_icon={true} />
            <div class="mt-2">
              <.listing :if={item.listing} listing={item.listing} />
              <.button
                :if={!item.listing}
                size={:sm}
                style={:secondary}
                phx-click={JS.patch(~p"/inventory/list_item/#{item.id}")}
              >
                List on the Market
              </.button>
            </div>
          </div>
        <% end %>
      </section>
    </article>
    <.modal
      :if={@live_action in [:new_listing, :edit_listing]}
      id="listing-modal"
      show
      on_cancel={JS.patch(~p"/inventory")}
    >
      <.live_component
        current_user={@current_user}
        module={DakkaWeb.ListingFormComponent}
        id={@listing.id || :new}
        title={@page_title}
        action={@live_action}
        listing={@listing}
        patch={~p"/inventory"}
      />
    </.modal>
    """
  end

  defp listing(assigns) do
    ~H"""
    <%= case @listing.status do %>
      <% :active -> %>
        <.button
          size={:sm}
          phx-click={JS.patch(~p"/inventory/edit_listing/#{@listing.user_game_item_id}")}
        >
          Listed on the Market <.icon name="hero-pencil-square" class="ml-1 h-5 w-5" />
        </.button>
      <% :expired -> %>
        <span class="bg-lime-400 text-gray-700 px-1 border border-lime-700">
          Listing expired
        </span>
      <% :sold -> %>
        <.link
          class="text-zinc-600 italic"
          patch={~p"/inventory/edit_listing/#{@listing.user_game_item_id}?relist=true"}
        >
          <span class="text-amber-300 font-bold">Sold </span> (click to relist)
        </.link>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    items = Inventory.list_user_items(socket.assigns.current_user)

    if connected?(socket) do
      Inventory.subscribe(socket.assigns.scope.current_user_id)
      Market.subscribe({:market, socket.assigns.current_user})
    end

    socket =
      socket
      |> stream(:items, items)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_info({Market, market_event}, socket) do
    {:noreply, handle_market_event(socket, market_event)}
  end

  def handle_info({Inventory, inventory_event}, socket) do
    {:noreply, handle_inventory_event(socket, inventory_event)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Inventory")
  end

  defp apply_action(socket, :new_listing, %{"id" => id}) do
    item = Inventory.get_user_item!(socket.assigns.current_user, id)

    socket
    |> assign(:page_title, "Inventory - Create Listing")
    |> assign(:listing, Market.build_listing(item))
  end

  defp apply_action(socket, :edit_listing, %{"id" => id} = params) do
    user = socket.assigns.current_user

    listing =
      user
      |> Market.get_listing_by_seller_item_id!(id)
      |> maybe_mark_relist(params)

    socket
    |> assign(:page_title, "Inventory - Edit Listing")
    |> assign(:listing, listing)
  end

  defp maybe_mark_relist(listing, %{"relist" => "true"}), do: %{listing | relist: true}
  defp maybe_mark_relist(listing, _), do: listing

  ## Market Events

  defp handle_market_event(socket, %event_mod{listing: listing})
       when event_mod in [
              ListingCreated,
              ListingDeleted,
              ListingExpired,
              ListingSold,
              ListingUpdated
            ] do
    stream_insert(
      socket,
      :items,
      Inventory.get_user_item!(socket.assigns.current_user, listing.user_game_item_id),
      at: -1
    )
  end

  defp handle_market_event(socket, _event) do
    socket
  end

  ## Inventory Events

  defp handle_inventory_event(socket, %UserItemCreated{user_item: item}) do
    socket
    |> stream_insert(:items, item, at: 0)
    |> push_event("highlight", %{id: "items-#{item.id}"})
  end
end
