defmodule DndahWeb.OffersLive do
  use DndahWeb, :live_view

  import DndahWeb.MarketComponents

  alias Dndah.Market

  alias Dndah.Market.Events.{
          OfferCreated,
          OfferDeclined,
          OfferCancelled,
          OfferAccepted
        },
        warn: false

  defp available_statuses() do
    [{"Default (Active + Accepted)", :default} | Market.ListingOffer.options()]
  end

  def render(assigns) do
    ~H"""
    <article class="flex divide-x divide-zinc-800 items-baseline">
      <section class="flex flex-col flex-1">
        <h2 class="text-center text-3xl text-gray-100">Incoming Offers</h2>
        <div class="xl:w-[50%] sm:w-[60%] w-full mx-auto">
          <.form for={@incoming_offers_filters_form} phx-change="filter-incoming-offers">
            <.input
              id="incoming-offers-filters-status"
              type="select"
              field={@incoming_offers_filters_form[:status]}
              options={available_statuses()}
            />
          </.form>
        </div>
        <div
          class="flex-1 mt-2 flex text-gray-100 flex-col justify-center space-y-4 p-4 divide-y divide-zinc-700"
          phx-update="stream"
          id="incoming_offers"
        >
          <.incoming_offer :for={{id, offer} <- @streams.incoming_offers} offer={offer} id={id}>
            <:actions>
              <span
                :if={offer.status == :active}
                phx-click={JS.push("accept-offer", value: %{id: offer.id})}
                class="text-sky-500 italic underline underline-offset-4 hover:cursor-pointer hover:text-sky-400"
              >
                Accept and open trade page
              </span>
              <.link
                :if={offer.status == :accepted_by_seller}
                patch={~p"/trade/#{offer.id}"}
                class="text-sky-500 italic underline underline-offset-4 hover:cursor-pointer hover:text-sky-400"
              >
                Open trade page
              </.link>
              <span
                :if={offer.status in [:active, :accepted_by_seller]}
                phx-click={JS.push("decline-offer", value: %{id: offer.id})}
                class="text-gray-500 italic underline underline-offset-4 hover:cursor-pointer hover:text-gray-400"
              >
                Decline
              </span>
            </:actions>
          </.incoming_offer>
        </div>
        <div class="mt-4 text-center">
          <span
            phx-click="load-more-incoming"
            class="text-blue-300 italic border-b border-dotted border-blue-300 hover:cursor-pointer"
          >
            Load More
          </span>
        </div>
      </section>
      <section class="flex-1">
        <h2 class="text-center text-3xl text-gray-100">Sent Offers</h2>
        <div class="xl:w-[50%] sm:w-[60%] w-full mx-auto">
          <.form for={@sent_offers_filters_form} phx-change="filter-sent-offers">
            <.input
              id="sent-offers-filters-status"
              type="select"
              field={@sent_offers_filters_form[:status]}
              options={available_statuses()}
            />
          </.form>
        </div>
        <div
          class="flex-1 mt-2 flex text-gray-100 flex-col justify-center space-y-4 p-4 divide-y divide-zinc-700"
          phx-update="stream"
          id="sent-offers"
        >
          <.sent_offer :for={{id, offer} <- @streams.sent_offers} offer={offer} id={id}>
            <:actions>
              <.link
                :if={offer.status == :accepted_by_seller}
                patch={~p"/trade/#{offer.id}"}
                class="text-sky-500 italic underline underline-offset-4 hover:cursor-pointer hover:text-sky-400"
              >
                Open trade page
              </.link>
              <span
                :if={offer.status in [:accepted_by_seller, :active]}
                phx-click={JS.push("decline-offer", value: %{id: offer.id})}
                class="text-gray-500 italic underline underline-offset-4 hover:cursor-pointer hover:text-gray-400"
              >
                Cancel offer
              </span>
            </:actions>
          </.sent_offer>
        </div>
        <div class="mt-4 text-center">
          <span
            phx-click="load-more-sent"
            class="text-blue-300 italic border-b border-dotted border-blue-300 hover:cursor-pointer"
          >
            Load More
          </span>
        </div>
      </section>
    </article>
    """
  end

  defp init_incoming_offers(socket) do
    socket
    |> assign(:incoming_offers_page, 1)
    |> assign(:incoming_offers_per_page, 20)
    |> assign(:incoming_offers_filters_form, filters_form())
    |> assign(:incoming_offers_filters, %{})
    |> paginate_incoming_offers(1)
  end

  defp init_sent_offers(socket) do
    socket
    |> assign(:sent_offers_page, 1)
    |> assign(:sent_offers_per_page, 20)
    |> assign(:sent_offers_filters_form, filters_form())
    |> assign(:sent_offers_filters, %{})
    |> paginate_sent_offers(1)
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Market.subscribe({:market, socket.assigns.scope.current_user})
    end

    socket =
      socket
      |> assign(:page_title, "Offers")
      |> init_sent_offers()
      |> init_incoming_offers()

    {:ok, socket}
  end

  def handle_event("filter-incoming-offers", %{"filters" => filters}, socket) do
    socket =
      socket
      |> assign(:incoming_offers_filters, filters)
      |> paginate_incoming_offers(1)

    {:noreply, socket}
  end

  def handle_event("filter-sent-offers", %{"filters" => filters}, socket) do
    socket =
      socket
      |> assign(:sent_offers_filters, filters)
      |> paginate_sent_offers(1)

    {:noreply, socket}
  end

  def handle_event("load-more-incoming", _params, socket) do
    %{incoming_offers_page: cur_page} = socket.assigns
    {:noreply, paginate_incoming_offers(socket, cur_page + 1)}
  end

  def handle_event("load-more-sent", _params, socket) do
    %{sent_offers_page: cur_page} = socket.assigns
    {:noreply, paginate_sent_offers(socket, cur_page + 1)}
  end

  def handle_event("accept-offer", %{"id" => offer_id}, socket) do
    case Market.accept_offer(socket.assigns.scope, offer_id) do
      {:ok, _offer} ->
        socket =
          socket
          |> push_navigate(to: ~p"/trade/#{offer_id}")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("decline-offer", %{"id" => offer_id}, socket) do
    case Market.decline_offer(socket.assigns.scope, offer_id) do
      {:ok, _offer} ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_info({Market, event}, socket) do
    {:noreply, handle_market_event(socket, event)}
  end

  ## Market Events

  defp handle_market_event(socket, %_{offer: offer} = event) do
    user = socket.assigns.scope.current_user

    buyer? = buyer?(offer, user)
    seller? = seller?(offer, user)

    cond do
      buyer? and seller? ->
        socket
        |> handle_buyer_event(event)
        |> handle_seller_event(event)

      seller? ->
        handle_seller_event(socket, event)

      buyer? ->
        handle_buyer_event(socket, event)

      true ->
        socket
    end
  end

  defp handle_seller_event(socket, %OfferCreated{offer: offer}) do
    socket
    |> stream_insert(:incoming_offers, offer, at: 0)
    |> push_event("highlight", %{id: "incoming_offers-#{offer.id}"})
  end

  defp handle_seller_event(socket, %_{offer: offer}) do
    socket
    |> stream_insert(:incoming_offers, offer, at: -1)
    |> push_event("highlight", %{id: "incoming_offers-#{offer.id}"})
  end

  defp handle_buyer_event(socket, %OfferCreated{offer: offer}) do
    socket
    |> stream_insert(:sent_offers, offer, at: 0)
    |> push_event("highlight", %{id: "sent_offers-#{offer.id}"})
  end

  defp handle_buyer_event(socket, %_{offer: offer}) do
    socket
    |> stream_insert(:sent_offers, offer, at: -1)
    |> push_event("highlight", %{id: "sent_offers-#{offer.id}"})
  end

  defp buyer?(offer, user), do: offer.user_id == user.id
  defp seller?(offer, user), do: offer.listing.user_game_item.user.id == user.id

  ## Pagination

  defp paginate_incoming_offers(socket, new_page) do
    %{
      incoming_offers_per_page: per_page,
      incoming_offers_page: cur_page,
      incoming_offers_filters: filters
    } = socket.assigns

    offset = (new_page - 1) * per_page

    statuses =
      case filters do
        %{"status" => status} ->
          to_statuses(status)

        _ ->
          to_statuses("default")
      end

    incoming_offers =
      Market.list_incoming_offers(socket.assigns.scope,
        statuses: statuses,
        offset: offset,
        limit: per_page
      )

    next_page = if Enum.empty?(incoming_offers), do: cur_page, else: new_page

    socket
    |> stream(:incoming_offers, incoming_offers, reset: new_page == 1, at: -1)
    |> assign(:incoming_offers_page, next_page)
  end

  defp paginate_sent_offers(socket, new_page) do
    %{
      sent_offers_per_page: per_page,
      sent_offers_page: cur_page,
      sent_offers_filters: filters
    } = socket.assigns

    offset = (new_page - 1) * per_page

    statuses =
      case filters do
        %{"status" => status} ->
          to_statuses(status)

        _ ->
          to_statuses("default")
      end

    sent_offers =
      Market.list_sent_offers(socket.assigns.scope,
        statuses: statuses,
        offset: offset,
        limit: per_page
      )

    next_page = if Enum.empty?(sent_offers), do: cur_page, else: new_page

    socket
    |> stream(:sent_offers, sent_offers, reset: new_page == 1, at: -1)
    |> assign(:sent_offers_page, next_page)
  end

  ## Filter helpers

  defp filters_form() do
    to_form(%{}, as: :filters)
  end

  defp to_statuses("default"), do: [:active, :accepted_by_seller]
  defp to_statuses(status) when is_binary(status), do: [String.to_existing_atom(status)]
  defp to_statuses(_), do: []
end
