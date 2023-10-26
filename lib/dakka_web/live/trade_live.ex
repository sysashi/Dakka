defmodule DakkaWeb.TradeLive do
  use DakkaWeb, :live_view

  import DakkaWeb.GameComponents
  import DakkaWeb.MarketComponents

  alias Dakka.Market
  alias Dakka.Market.Events.TradeMessage

  def render(assigns) do
    ~H"""
    <article class="max-w-xl mx-auto ">
      <div class="mb-2 space-x-2">
        <.user_presence
          label="Seller"
          user={@seller}
          status={@seller_status}
          current_user?={@current_user.id == @seller.id}
        />

        <.user_presence
          label="Buyer"
          user={@buyer}
          status={@buyer_status}
          current_user?={@current_user.id == @buyer.id}
        />
      </div>

      <div class="bg-zinc-950 max-w-xl mx-auto flex border border-indigo-900 rounded-md flex-col">
        <section
          phx-hook="ChatAutoScroll"
          phx-update="stream"
          id="messages"
          class="flex flex-col p-2 space-y-4 h-[600px] overflow-auto"
        >
          <div
            :for={{id, message} <- @streams.messages}
            id={id}
            class={"max-w-[50%] #{message_aligment(@current_user, message.from)}"}
          >
            <.message
              message={message}
              from_current_user?={message_from_current_user?(@current_user, message.from)}
            />
          </div>
        </section>
        <section class="bg-black px-2 py-4 rounded-b-md border-t border-indigo-900">
          <.form
            for={@message_form}
            phx-submit="send-user-message"
            phx-change="validate-user-message"
            id="user-message-form"
          >
            <div class="flex items-center w-full justify-center space-x-2">
              <.input
                autocomplete="off"
                type="text"
                field={@message_form[:body]}
                class!="bg-zinc-800 border border-zinc-700 text-white"
              />
              <button
                type="submit"
                class={[
                  "px-4 py-2 bg-blue-700 text-white border border-blue-500 inline-flex",
                  "hover:bg-blue-800"
                ]}
              >
                Send
              </button>
            </div>
          </.form>
        </section>
      </div>
      <p class="text-gray-500 text-center mt-2">
        <.icon name="hero-exclamation-circle-mini" class="mb-1 h-5 w-5 flex-none text-pink-700" />
        Chat messages will disappear once you close this window
      </p>
    </article>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    case Market.find_listing_offer(socket.assigns.current_user, id) do
      {:ok, offer} ->
        if connected?(socket) do
          Market.subscribe(offer)
          DakkaWeb.Presence.subscribe(offer)
          DakkaWeb.Presence.track_trade(offer, socket.assigns.current_user)
        end

        socket =
          socket
          |> assign(:offer, offer)
          |> assign(:seller, offer.listing.user_game_item.user)
          |> assign(:buyer, offer.user)
          |> assign_message_form()
          |> stream(:messages, initial_messages(offer))
          |> assign_presences()

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, push_navigate(socket, to: return_to(socket))}
    end
  end

  def handle_event("validate-user-message", %{"message" => %{"body" => body}}, socket) do
    {:noreply, assign_message_form(socket, body)}
  end

  def handle_event("send-user-message", %{"message" => %{"body" => body}}, socket) do
    body = String.trim(body)

    if body != "" do
      message = build_user_message(socket.assigns.current_user, body)
      Market.send_trade_message(socket.assigns.offer, message)

      socket =
        socket
        |> assign_message_form()
        |> stream_insert(:messages, message, at: -1)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp build_user_message(user, body) do
    %{
      id: Ecto.UUID.generate() <> "#{user.id}",
      from: user,
      body: body,
      type: :user_message
    }
  end

  def handle_info({Market, %TradeMessage{message: message}}, socket) do
    {:noreply, stream_insert(socket, :messages, message, at: -1)}
  end

  def handle_info({DakkaWeb.Presence, {:user_joined, presence}}, socket) do
    {:noreply, assign_presence(socket, presence)}
  end

  def handle_info({DakkaWeb.Presence, {:user_left, presence}}, socket) do
    %{user: left_user} = presence

    if presence.metas == [] do
      {:noreply, remove_presence(socket, left_user)}
    else
      {:noreply, socket}
    end
  end

  def assign_message_form(socket, body \\ "") do
    assign(socket, :message_form, to_form(%{"body" => body}, as: :message))
  end

  def message_form(body \\ "") do
    to_form(%{"body" => body}, as: :message)
  end

  defp message_aligment(_, :system), do: "mx-auto"
  defp message_aligment(%{id: id}, %{id: id}), do: "ml-auto"
  defp message_aligment(_, _), do: "mr-auto"
  defp message_from_current_user?(%{id: id}, %{id: id}), do: true
  defp message_from_current_user?(_, _), do: false

  defp return_to(%{assigns: %{return_to: path}}), do: path
  defp return_to(_socket), do: "/"

  defp initial_messages(offer) do
    [
      %{
        id: "listing-#{offer.listing.id}",
        listing: offer.listing,
        type: :listing,
        from: offer.listing.user_game_item.user
      },
      %{
        id: "offer-#{offer.id}",
        offer: offer,
        type: :offer,
        from: offer.user
      }
    ]
  end

  attr :message, :any, required: true
  attr :from_current_user?, :boolean, default: false

  defp message(%{message: message} = assigns) do
    assigns
    |> assign(:type, message.type)
    |> update(:message, &Map.put_new(&1, :from_current_user?, assigns.from_current_user?))
    |> typed_message()
  end

  defp typed_message(%{type: :listing} = assigns) do
    listing_message(assigns.message)
  end

  defp typed_message(%{type: :offer} = assigns) do
    offer_message(assigns.message)
  end

  defp typed_message(%{type: :system} = assigns) do
    system_message(assigns.message)
  end

  defp typed_message(%{type: :user_message} = assigns) do
    text_message(assigns.message)
  end

  defp listing_message(assigns) do
    ~H"""
    <div class="text-center">
      <span class="text-white py-1 font-semibold"> Listing </span>
      <.listing listing={@listing} />
    </div>
    """
  end

  defp offer_message(assigns) do
    ~H"""
    <div class="text-center">
      <span class="text-white py-1 font-semibold"> Offer </span>
      <div class="flex bg-zinc-800 flex-col text-center p-1 border border-zinc-700">
        <.gold :if={@offer.offer_gold_amount} amount={@offer.offer_gold_amount} />
        <.golden_key :if={@offer.offer_golden_keys_amount} amount={@offer.offer_golden_keys_amount} />
      </div>
    </div>
    """
  end

  defp system_message(assigns) do
    ~H"""
    <div class="text-center">
      <span class="bg-red-400 rounded-md font-bold text-white px-1 py-[2px]"> System </span>
      <div class="px-2 py-1 text-white rounded-md bg-gray-700 text-center font-bold mt-1">
        <%= @body %>
      </div>
    </div>
    """
  end

  defp text_message(assigns) do
    ~H"""
    <div
      phx-mounted={JS.transition({"ease-out duration-300", "opacity-0", "opacity-100"})}
      class={[
        "px-2 py-1 text-white rounded-md break-all",
        if(@from_current_user?, do: "bg-indigo-600", else: "bg-green-600")
      ]}
    >
      <%= @body %>
    </div>
    """
  end

  ## Presence Helpers

  defp assign_presences(socket) do
    socket = assign(socket, seller_status: :waiting, buyer_status: :waiting)

    if offer = connected?(socket) && socket.assigns.offer do
      offer
      |> DakkaWeb.Presence.list_trade_users()
      |> Enum.reduce(socket, fn {_, presence}, acc -> assign_presence(acc, presence) end)
    else
      socket
    end
  end

  defp assign_presence(socket, presence) do
    %{user: connected_user} = presence
    %{seller: seller, buyer: buyer} = socket.assigns

    assigns =
      cond do
        connected_user.id == seller.id ->
          %{seller_status: :connected}

        connected_user.id == buyer.id ->
          %{buyer_status: :connected}

        true ->
          %{}
      end

    assign(socket, assigns)
  end

  defp remove_presence(socket, left_user) do
    %{seller: seller, buyer: buyer} = socket.assigns

    assigns =
      cond do
        left_user.id == seller.id ->
          %{seller_status: :left}

        left_user.id == buyer.id ->
          %{buyer_status: :left}

        true ->
          %{}
      end

    assign(socket, assigns)
  end

  attr :user, :any
  attr :label, :string
  attr :connected_color, :string, default: "text-gray-100"
  attr :current_user?, :boolean
  attr :status, :atom, values: [:connected, :left, :waiting]

  def user_presence(assigns) do
    ~H"""
    <div class={[
      "flex-col inline-flex items-center",
      @status == :waiting && "animate-pulse text-gray-700",
      @status == :connected && if(@current_user?, do: "text-indigo-600", else: "text-green-600"),
      @status == :left && "text-pink-900"
    ]}>
      <span class="bg-gray-400 text-center text-gray-900 text-xs px-1">
        <%= @label %>
      </span>
      <.icon name="hero-user-circle" class="mt-0.5 h-12 w-12 flex-none" />
      <span class="text-center text-xs">
        <%= case @status do %>
          <% :connected -> %>
            <%= @user.username %>
          <% :waiting -> %>
            Waiting...
          <% :left -> %>
            Left
        <% end %>
      </span>
    </div>
    """
  end
end
