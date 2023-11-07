defmodule DakkaWeb.MarketLive.QuickBuyDialogComponent do
  use DakkaWeb, :live_component

  import DakkaWeb.MarketComponents

  alias Dakka.Market.Events.{
    ListingDeleted,
    ListingExpired,
    ListingSold,
    ListingUpdated
  }

  @impl true
  def render(assigns) do
    ~H"""
    <article class="text-zinc-200 w-full sm:w-96 space-y-4">
      <h2 class="text-2xl">Quick Buy</h2>

      <section class="relative">
        <article class="space-y-4">
          <div class="text-gray-100 bg-blue-600/30  mt-4 p-2 text-md">
            <.icon name="hero-information-circle-mini" class="mb-[3px] h-4 w-4" /> Notice
            <p class="mt-2 ml-2">
              Make sure you have all necessary items for trade
            </p>
          </div>
          <div class="bg-zinc-900 p-4 border border-zinc-700">
            <.listing listing={@listing} display_settings={@settings.display} />
          </div>

          <.button size={:md} class="w-full" phx-click="confirm" phx-target={@myself}>
            I confirm that I enough currency to perform a trade
          </.button>

          <div
            :if={@show_trade_details}
            class="w-full text-center leading-7"
            phx-mounted={JS.transition({"ease-out duration-1000", "opacity-0", "opacity-100"})}
            }
          >
            <h3 class="text-xl">You can find the seller at:</h3>
            <ul>
              <li>Trade outpost: <b> Misc </b></li>
              <li>
                Character Name:
                <span class="font-bold">
                  <%= @listing.user_game_character.name %>
                </span>
              </li>
              <li :if={char_class = @listing.user_game_character.class}>
                Character Class:
                <span class="font-bold">
                  <%= char_class %>
                </span>
              </li>
            </ul>
          </div>
        </article>
        <!-- mask -->
        <div
          :if={@disabled}
          class="bg-gray-900/80 border border-red-900/50 absolute inset-0 flex items-center justify-center flex-col space-y-4 backdrop-blur-sm"
        >
          <span class="text-2xl font-bold text-gray-100 mx-12 text-center">
            <%= @disable_reason || @listing.status %>
          </span>
          <span :if={@auto_close_timer_ref}>
            This window will close shortly
          </span>
        </div>
      </section>
    </article>
    """
  end

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:disabled, false)
      |> assign(:disable_reason, nil)
      |> assign(:show_trade_details, false)
      |> assign(:auto_close_timer_ref, nil)

    {:ok, socket}
  end

  @impl true
  def update(%{seller: :offline}, socket) do
    {:ok, disable_with_reason(socket, "Seller Offline")}
  end

  def update(%{listing_event: event}, socket) do
    {:ok, handle_listing_event(socket, event)}
  end

  def update(%{auto_close: true}, socket) do
    socket =
      socket
      |> push_patch(to: socket.assigns.patch)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:show_trade_details, false)
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("confirm", _, socket) do
    {:noreply, assign(socket, :show_trade_details, true)}
  end

  defp handle_listing_event(socket, %ListingUpdated{listing: listing}) do
    socket = assign(socket, :listing, listing)

    if !listing.quick_sell do
      disable_with_reason(socket, "Listing is no longer available for Quick Buy")
    else
      revert_disabled(socket)
    end
  end

  defp handle_listing_event(socket, %ListingDeleted{}) do
    disable_with_reason(socket, "Listing Removed")
  end

  defp handle_listing_event(socket, %ListingSold{}) do
    disable_with_reason(socket, "Listing Sold")
  end

  defp handle_listing_event(socket, %ListingExpired{}) do
    disable_with_reason(socket, "Listing Expired")
  end

  defp disable_with_reason(socket, reason) do
    timer_ref =
      Process.send_after(self(), {:close_quick_buy_dialog, socket.assigns.listing.id}, 5000)

    socket
    |> assign(:disabled, true)
    |> assign(:disable_reason, reason)
    |> assign(:show_trade_details, false)
    |> assign(:auto_close_timer_ref, timer_ref)
  end

  defp revert_disabled(socket) do
    if ref = socket.assigns.auto_close_timer_ref do
      Process.cancel_timer(ref)
    end

    socket
    |> assign(:disabled, false)
    |> assign(:disable_reason, nil)
    |> assign(:auto_close_timer_ref, nil)
  end
end
