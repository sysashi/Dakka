defmodule DndahWeb.MarketLive do
  use DndahWeb, :live_view

  import DndahWeb.MarketComponents

  alias Dndah.Market

  alias Dndah.Market.Events.{
    ListingCreated,
    ListingDeleted,
    ListingExpired,
    ListingSold,
    ListingUpdated,
    OfferAccepted,
    OfferCancelled,
    OfferCreated,
    OfferDeclined
  }

  # Container
  # "[&:nth-child(6n+4)]:border-y [&:nth-child(6n+5)]:border-y [&:nth-child(6n+6)]:border-y",
  # "[&:nth-child(6n+4)]:py-4 [&:nth-child(6n+5)]:py-4 [&:nth-child(6n+6)]:py-4"
  # Items
  # "group-[:nth-child(6n+1)]:bg-red-300",
  # "group-[:nth-child(6n+2)]:bg-red-300",
  # "group-[:nth-child(6n+3)]:bg-red-300"

  def render(assigns) do
    ~H"""
    <div class="mx-auto mb-4 ">
      <h4
        class="text-xl text-gray-200 text-right hover:text-gray-300 hover:cursor-pointer p-2 font-bold hover:underline"
        phx-click={
          JS.toggle(to: ".filter-toggle")
          |> JS.toggle(
            to: "#filters-form",
            in: {"duration-150", "scale-y-0 max-h-0", "scale-y-100 max-h-[500px]"},
            out: {"duration-150", "scale-y-100 max-h-[500px]", "scale-y-0 max-h-0"}
          )
        }
      >
        <span class="filter-toggle">
          Show Filters <.icon name="hero-arrow-down" class="mr-1 h-4" />
        </span>
        <span class="filter-toggle hidden">
          Hide Filters <.icon name="hero-arrow-up" class="mr-1 h-4 w-4" />
        </span>
      </h4>

      <article
        class="bg-zinc-800 border border-zinc-700 transition-all origin-top hidden"
        id="filters-form"
      >
        <.live_component module={DndahWeb.MarketLive.ListingFiltersFormComponent} id="filters" />
      </article>
    </div>

    <section class="flex mx-auto flex-col">
      <div
        class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-y-8 gap-x-4 auto-rows-max mx-auto text-white flex-1 overflow-auto"
        phx-update="stream"
        id="market"
        phx-viewport-top={@page > 1 && "prev-page"}
        phx-viewport-bottom={!@end_of_timeline? && "next-page"}
        phx-page-loading
        class={[
          if(@end_of_timeline?, do: "pb-10", else: "pb-[calc(200vh)]"),
          if(@page == 1, do: "pt-10", else: "pt-[calc(200vh)]")
        ]}
      >
        <div
          :for={{id, listing} <- @streams.listings}
          id={id}
          class={[
            "max-w-xs mx-auto border-zinc-500/10"
          ]}
        >
          <.listing listing={listing} show_icon={false}>
            <:actions :if={@scope.current_user_id}>
              <div
                class={[
                  "flex items-center gap-2 mt-2 group-hover:bg-blue-700"
                ]}
                if={listing.status == :active}
              >
                <%= case listing.offers do %>
                  <% [offer] -> %>
                    <span
                      :if={offer.status == :active}
                      class="animate-pulse font-semibold text-sm text-center flex justify-center items-center flex-1 text-zinc-500"
                    >
                      Awaiting Response
                    </span>
                    <.link
                      :if={offer.status == :accepted_by_seller}
                      patch={~p"/trade/#{offer.id}"}
                      class={[
                        "font-semibold text-sm px-2 py-1 border inline-flex self-stretch items-center",
                        "bg-blue-700 hover:bg-blue-800 border-blue-500 text-white w-full"
                      ]}
                    >
                      <.icon name="hero-check-circle" class="mr-1 h-5 w-5" />
                      Accepted. Open Trade Window
                    </.link>
                  <% _ -> %>
                    <.button
                      :if={price_set?(listing)}
                      size={:sm}
                      style={:secondary}
                      phx-click={JS.push("create-offer", value: %{id: listing.id})}
                    >
                      <.icon name="hero-circle-stack" class="text-yellow-400 mr-1 h-5 w-5" /> Buy
                    </.button>
                    <.link
                      :if={listing.open_for_offers}
                      patch={~p"/market/offer/#{listing.id}"}
                      class={[
                        "font-semibold text-sm px-2 py-1 bg-zinc-800 border border-zinc-700 inline-flex self-stretch items-center",
                        "hover:bg-green-900 text-zinc-100 transition-colors duration-100"
                      ]}
                    >
                      <.icon name="hero-swatch" class="text-blue-400 mr-1 h-5 w-5" /> Custom Offer
                    </.link>
                <% end %>
              </div>
            </:actions>
          </.listing>
        </div>
      </div>
    </section>
    <.modal
      :if={@live_action in [:new_offer]}
      id="listing-modal"
      show
      on_cancel={JS.patch(~p"/market")}
    >
      <.live_component
        id={:new}
        scope={@scope}
        module={DndahWeb.MarketLive.OfferFormComponent}
        title={@page_title}
        action={@live_action}
        offer={@offer}
        listing_id={@listing_id}
        patch={~p"/market"}
      />
    </.modal>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Market.subscribe()

      if current_user = socket.assigns.scope.current_user do
        Market.subscribe({:market, current_user})
      end
    end

    socket =
      socket
      |> assign(page: 1, per_page: 20)
      |> paginate_listings(1)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Market")
  end

  defp apply_action(socket, :new_offer, %{"listing_id" => listing_id}) do
    scope = socket.assigns.scope
    listing = Market.get_listing!(listing_id)

    socket
    |> assign(:page_title, "Market - Create Offer")
    |> assign(:offer, Market.build_offer(scope, listing))
    |> assign(:listing_id, listing.id)
  end

  def handle_event("next-page", _, socket) do
    {:noreply, paginate_listings(socket, socket.assigns.page + 1)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, paginate_listings(socket, 1)}
  end

  def handle_event("prev-page", _, socket) do
    if socket.assigns.page > 1 do
      {:noreply, paginate_listings(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("create-offer", %{"id" => listing_id}, socket) do
    listing = Market.get_listing!(listing_id, user_game_item: :user)

    case Market.create_offer(
           socket.assigns.scope,
           listing.id,
           %{
             offer_gold_amount: listing.price_gold,
             offer_golden_keys_amount: listing.price_golden_keys
           },
           buyout?: true
         ) do
      {:ok, _offer} ->
        # listing = Market.get_listing_with_buyer_offers!(listing.id, socket.assigns.current_user)

        # socket =
        #   socket
        #   |> stream_insert(:listings, listing)
        #   |> push_event("highlight", %{id: "listings-#{listing.id}"})

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_info({:search, filters}, socket) do
    socket = stream(socket, :listings, [], reset: true)
    {:noreply, paginate_listings(socket, 1, filters)}
  end

  def handle_info({Market, %ListingCreated{listing: listing}}, socket) do
    socket =
      socket
      |> stream_insert(:listings, listing, at: 0)
      |> push_event("highlight", %{id: "listings-#{listing.id}"})

    {:noreply, socket}
  end

  def handle_info({Market, %ListingDeleted{listing: listing}}, socket) do
    socket = stream_delete(socket, :listings, listing)
    {:noreply, socket}
  end

  def handle_info({Market, %mod{listing: listing}}, socket)
      when mod in [
             ListingExpired,
             ListingSold,
             ListingUpdated
           ] do
    listing = Market.get_listing_with_buyer_offers!(listing.id, socket.assigns.scope)

    socket =
      socket
      |> stream_insert(:listings, listing, at: -1)
      |> push_event("highlight", %{id: "listings-#{listing.id}"})

    {:noreply, socket}
  end

  def handle_info({Market, %mod{offer: offer}}, socket)
      when mod in [
             OfferAccepted,
             OfferCancelled,
             OfferCreated,
             OfferDeclined
           ] do
    listing = Market.get_listing_with_buyer_offers!(offer.listing_id, socket.assigns.scope)

    socket =
      socket
      |> stream_insert(:listings, listing, at: -1)
      |> push_event("highlight", %{id: "listings-#{listing.id}"})

    {:noreply, socket}
  end

  defp paginate_listings(socket, new_page, filters \\ []) do
    %{per_page: per_page, page: cur_page} = socket.assigns
    offset = (new_page - 1) * per_page

    listings =
      Market.search_listings(socket.assigns.scope,
        offset: offset,
        limit: per_page,
        filters: filters
      )

    {listings, at, limit} =
      if new_page >= cur_page do
        {listings, -1, per_page * 3 * -1}
      else
        {Enum.reverse(listings), 0, per_page * 3}
      end

    case listings do
      [] ->
        assign(socket, end_of_timeline?: at == -1)

      [_ | _] = listings ->
        socket
        |> assign(end_of_timeline?: false)
        |> assign(:page, new_page)
        |> stream(:listings, listings, at: at, limit: limit)
    end
  end

  defp price_set?(listing) do
    listing.price_gold || listing.price_golden_keys
  end
end
