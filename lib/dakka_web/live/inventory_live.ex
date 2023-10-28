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

  alias Dakka.Inventory.Events.{
    UserItemCreated,
    UserItemDeleted
  }

  def render(assigns) do
    ~H"""
    <div class="mb-4 border-b border-zinc-700 pb-4">
      <h3 class="text-center mb-2 text-2xl text-gray-500">Add new item</h3>
      <.live_component
        module={DakkaWeb.Inventory.AddItemLive}
        id="add-item"
        scope={@scope}
        display_settings={@settings.display}
      />
    </div>
    <article class="flex text-white">
      <section
        id="user-items"
        class="grid grid-cols-1 px-10 sm:px-0 mx-auto sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-x-2 gap-y-4 auto-rows-max items-baseline"
        phx-update="stream"
        phx-viewport-top={@page > 1 && "prev-page"}
        phx-viewport-bottom={!@end_of_timeline? && "next-page"}
        phx-page-loading
        class={[
          if(@end_of_timeline?, do: "pb-10", else: "pb-[calc(200vh)]"),
          if(@page == 1, do: "pt-10", else: "pt-[calc(200vh)]")
        ]}
      >
        <%= for {id, item} <- @streams.items do %>
          <div class="flex flex-col" id={id}>
            <.item_card item={item} display_settings={@settings.display} />
            <div class="mt-2 flex justify-between items-center">
              <.listing_actions :if={item.listing} listing={item.listing} />
              <.button
                :if={!item.listing}
                size={:sm}
                style={:secondary}
                phx-click={JS.patch(~p"/inventory/list_item/#{item.id}")}
              >
                List on the Market
              </.button>
              <span
                class="bg-red-800 p-1 border border-red-900 hover:border-red-600 hover:bg-red-700 hover:cursor-pointer group transition-colors duration-150"
                phx-click={JS.push("delete-item", value: %{item_id: item.id})}
                data-confirm="Removing this item will also delete all listings and decline active offers, proceed?"
              >
                <.icon name="hero-trash" class="w-5 h-5 text-red-200 mb-0.5 group-hover:text-red-100" />
              </span>
            </div>
          </div>
        <% end %>
      </section>
    </article>
    <div :if={@end_of_timeline? && @page > 1} class="mt-5 text-xl text-zinc-500 italic text-center">
      <.skelly class="rotateZ w-10 h-10 text-zinc-500" />
      <span>Nothing left</span>
      <.skelly class="rotateZ w-10 h-10 text-zinc-500" />
    </div>
    <.modal
      :if={@live_action in [:new_listing, :edit_listing]}
      id="listing-modal"
      show
      on_cancel={JS.patch(~p"/inventory")}
    >
      <.live_component
        scope={@scope}
        module={DakkaWeb.MarketLive.ListingFormComponent}
        id={@listing.id || :new}
        title={@page_title}
        action={@live_action}
        listing={@listing}
        patch={~p"/inventory"}
      />
    </.modal>
    """
  end

  defp listing_actions(assigns) do
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
    %{scope: scope} = socket.assigns

    if connected?(socket) do
      Market.subscribe(scope)
      Inventory.subscribe(scope)
    end

    socket =
      socket
      |> stream(:items, [])
      |> assign(page: 1, per_page: 20)
      |> paginate_items(1)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_event("delete-item", %{"item_id" => item_id}, socket) do
    case Inventory.delete_user_item(socket.assigns.scope, item_id) do
      {:ok, item} ->
        {:noreply, stream_delete(socket, :items, item)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Error occured")}
    end
  end

  def handle_event("next-page", _, socket) do
    {:noreply, paginate_items(socket, socket.assigns.page + 1)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, paginate_items(socket, 1)}
  end

  def handle_event("prev-page", _, socket) do
    if socket.assigns.page > 1 do
      {:noreply, paginate_items(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
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
    item = Inventory.get_user_item!(socket.assigns.scope, id)

    socket
    |> assign(:page_title, "Inventory - Create Listing")
    |> assign(:listing, Market.build_listing(item))
  end

  defp apply_action(socket, :edit_listing, %{"id" => id} = params) do
    listing =
      socket.assigns.scope
      |> Market.get_listing_by_seller_item_id!(id)
      |> maybe_mark_relist(params)

    socket
    |> assign(:page_title, "Inventory - Edit Listing")
    |> assign(:listing, listing)
  end

  defp maybe_mark_relist(listing, %{"relist" => "true"}), do: %{listing | relist: true}
  defp maybe_mark_relist(listing, _), do: listing

  defp paginate_items(socket, new_page) do
    %{per_page: per_page, page: cur_page} = socket.assigns
    offset = (new_page - 1) * per_page

    items =
      Inventory.list_user_items(
        socket.assigns.scope,
        offset: offset,
        limit: per_page
      )

    {items, at, limit} =
      if new_page >= cur_page do
        {items, -1, per_page * 3 * -1}
      else
        {Enum.reverse(items), 0, per_page * 3}
      end

    case items do
      [] ->
        assign(socket, end_of_timeline?: at == -1)

      [_ | _] = items ->
        socket
        |> assign(end_of_timeline?: false)
        |> assign(:page, new_page)
        |> stream(:items, items, at: at, limit: limit)
    end
  end

  ## Market Events

  defp handle_market_event(socket, %event_mod{listing: listing})
       when event_mod in [
              ListingCreated,
              ListingDeleted,
              ListingExpired,
              ListingSold,
              ListingUpdated
            ] do
    # Have to check if item is still avaiable (not deleted)
    case Inventory.find_user_item(socket.assigns.scope, listing.user_game_item_id) do
      {:ok, item} ->
        stream_insert(socket, :items, item, at: -1)

      {:error, :not_found} ->
        socket
    end
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

  defp handle_inventory_event(socket, %UserItemDeleted{user_item: item}) do
    socket
    |> push_event("highlight", %{id: "items-#{item.id}"})
    |> stream_delete(:items, item)
  end
end
