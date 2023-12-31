defmodule DakkaWeb.OffersLive do
  use DakkaWeb, :live_view

  require Logger

  import DakkaWeb.MarketComponents

  alias Dakka.Market

  alias Dakka.Market.Events.{
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
    <article class="sm:flex sm:divide-x sm:divide-zinc-800 items-baseline">
      <section class="flex flex-col flex-1">
        <h2 class="text-center text-2xl md:text-3xl text-gray-100">Incoming Offers</h2>
        <div class="xl:w-[50%] sm:w-[60%] w-full mx-auto mt-1">
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
          <.incoming_offer
            :for={{id, offer} <- @streams.incoming_offers}
            id={id}
            offer={offer}
            display_settings={@settings.display}
          >
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
      <section class="flex-1 mt-4 border-t border-blue-300 border-dashed sm:mt-0 sm:border-t-0">
        <h2 class="text-center text-2xl md:text-3xl text-gray-100 mt-2 sm:mt-0">Sent Offers</h2>
        <div class="xl:w-[50%] sm:w-[60%] w-full mx-auto mt-1">
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
          <.sent_offer
            :for={{id, offer} <- @streams.sent_offers}
            display_settings={@settings.display}
            offer={offer}
            id={id}
          >
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
                phx-click={JS.push("cancel-offer", value: %{id: offer.id})}
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
    %{scope: scope} = socket.assigns

    if connected?(socket) do
      Market.subscribe(scope)
    end

    Market.read_offer_notifications(
      scope,
      [:offer_created, :offer_cancelled, :offer_accepted, :offer_declined],
      :all
    )

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

      {:error, {:unacceptable_status, status}} ->
        status = Market.ListingOffer.humanize_status(status)
        message = "Can't accept offer with status: #{status}"
        {:noreply, put_flash(socket, :error, message)}

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

  def handle_event("cancel-offer", %{"id" => offer_id}, socket) do
    case Market.cancel_offer(socket.assigns.scope, offer_id) do
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

  defp handle_market_event(socket, %event_mod{}) do
    Logger.debug("OffersLive: ignoring market event - #{event_mod}")
    socket
  end

  defp handle_seller_event(socket, %OfferCreated{offer: offer}) do
    Market.read_offer_notifications(
      socket.assigns.scope,
      [:offer_created],
      [offer.id]
    )

    socket
    |> stream_insert(:incoming_offers, offer, at: 0)
    |> push_event("highlight", %{id: "incoming_offers-#{offer.id}"})
  end

  defp handle_seller_event(socket, %event_mod{offer: offer}) do
    if event_mod == OfferCancelled do
      Market.read_offer_notifications(
        socket.assigns.scope,
        [:offer_cancelled],
        [offer.id]
      )
    end

    socket
    |> stream_insert(:incoming_offers, offer, at: -1)
    |> push_event("highlight", %{id: "incoming_offers-#{offer.id}"})
  end

  defp handle_buyer_event(socket, %OfferCreated{offer: offer}) do
    socket
    |> stream_insert(:sent_offers, offer, at: 0)
    |> push_event("highlight", %{id: "sent_offers-#{offer.id}"})
  end

  defp handle_buyer_event(socket, %event_mod{offer: offer}) do
    if event_mod in [OfferAccepted, OfferDeclined] do
      Market.read_offer_notifications(
        socket.assigns.scope,
        [:offer_accepted, :offer_declined],
        [offer.id]
      )
    end

    socket
    |> stream_insert(:sent_offers, offer, at: -1)
    |> push_event("highlight", %{id: "sent_offers-#{offer.id}"})
  end

  defp buyer?(offer, user), do: offer.user_id == user.id
  defp seller?(offer, user), do: offer.listing.user_game_item.user.id == user.id

  ## Pagination

  defp paginate_incoming_offers(socket, new_page) do
    %{
      scope: scope,
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
      Market.list_incoming_offers(scope,
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
      scope: scope,
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
      Market.list_sent_offers(
        scope,
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
