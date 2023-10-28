defmodule DakkaWeb.MarketComponents do
  use Phoenix.Component

  import DakkaWeb.GameComponents

  alias Dakka.Accounts.UserSettings.Display

  attr :show_price, :boolean, default: true
  attr :listing, :any, required: true
  attr :item_attrs, :any, default: []
  attr :rest, :global, include: ~w(show_properties show_flavor_text show_icon)
  attr :display_settings, Display

  slot :header
  slot :actions

  def listing(assigns) do
    ~H"""
    <article>
      <div class="ml-[60px]">
        <%= render_slot(@header) %>
      </div>
      <div class="flex">
        <div
          :if={@show_price}
          class={"mr-2 space-y-2 items-baseline max-w-[60px] #{@listing.status != :active && "grayscale"}"}
        >
          <div :if={@listing.price_gold} class="bg-zinc-800 border border-zinc-700 px-2">
            <.gold amount={@listing.price_gold} />
          </div>
          <div :if={@listing.price_golden_keys} class="bg-zinc-800 border border-zinc-700 px-2">
            <.golden_key amount={@listing.price_golden_keys} />
          </div>
          <div
            :if={@listing.open_for_offers}
            class="bg-zinc-800 border border-zinc-700 px-2 text-left leading-[70%] py-2"
          >
            <span class="text-[12px] font-semibold capitalize text-sky-300">
              open for offers
            </span>
          </div>
        </div>
        <div class="flex-1">
          <div class="relative">
            <.item_card item={@listing.user_game_item} display_settings={@display_settings} />
            <div
              :if={@listing.status != :active}
              class="bg-gray-900/50 border border-red-900/50 absolute inset-0 flex items-center justify-center"
            >
              <span class="text-2xl font-bold text-gray-100 capitalize"><%= @listing.status %></span>
            </div>
          </div>
          <div :if={@listing.status == :active} class="flex-none">
            <%= render_slot(@actions) %>
          </div>
        </div>
      </div>
    </article>
    """
  end

  attr :id, :any
  attr :offer, :any, required: true
  attr :display_settings, Display

  slot :actions

  def incoming_offer(assigns) do
    ~H"""
    <article class="space-y-2" id={@id}>
      <div class="px-4 flex items-center justify-center space-x-2 mt-4">
        <span class="font-semibold"><%= @offer.user.username %></span>
        <%= if buyout?(@offer) do %>
          <span>wants to buy your</span>
        <% else %>
          <span> offered </span>
          <div class="flex items-baseline">
            <div :if={@offer.offer_gold_amount} class="">
              <.gold amount={@offer.offer_gold_amount} />
            </div>
            <div :if={@offer.offer_golden_keys_amount} class="">
              <.golden_key amount={@offer.offer_golden_keys_amount} />
            </div>
          </div>
          <span> for </span>
        <% end %>
        <div class="relative">
          <.item_title
            item={@offer.listing.user_game_item}
            class="peer hover:cursor-pointer hover:brightness-125 transition-all"
          />
          <div class="absolute hidden peer-hover:inline-flex peer-hover:z-20 w-96 top-[100%] -right-[50%] ml-2 backdrop-blur-md p-4 rounded-xl">
            <.listing listing={@offer.listing} display_settings={@display_settings} />
          </div>
        </div>
      </div>
      <!-- -->
      <div class="flex justify-center gap-4">
        <%= render_slot(@actions) %>
      </div>

      <div class="text-center">
        <span class="font-mono text-sm px-[2px] py-[1px] text-zinc-600">
          <%= relative_ts(@offer.inserted_at) %> | <.offer_status status={@offer.status} />
        </span>
      </div>
    </article>
    """
  end

  attr :id, :any
  attr :offer, :any, required: true
  attr :display_settings, Display

  slot :actions

  def sent_offer(assigns) do
    ~H"""
    <article id={@id} class="space-y-2 group">
      <div class="px-4 mt-4 flex items-center  justify-center space-x-2">
        <span>You offered</span>
        <%= if buyout?(@offer) do %>
          <span>to buy</span>
        <% else %>
          <div class="flex items-baseline">
            <div :if={@offer.offer_gold_amount} class="">
              <.gold amount={@offer.offer_gold_amount} />
            </div>
            <div :if={@offer.offer_golden_keys_amount} class="">
              <.golden_key amount={@offer.offer_golden_keys_amount} />
            </div>
          </div>
          <span> for </span>
        <% end %>
        <div class="relative">
          <.item_title
            item={@offer.listing.user_game_item}
            class="peer hover:cursor-pointer hover:brightness-125 transition-all"
          />
          <div class="absolute hidden peer-hover:inline-flex peer-hover:z-20 w-96 top-[100%] right-0 ml-2 backdrop-blur-md p-4 rounded-xl">
            <.listing listing={@offer.listing} display_settings={@display_settings} />
          </div>
        </div>
      </div>

      <div class="flex justify-center gap-4">
        <%= render_slot(@actions) %>
      </div>

      <div class="text-center text-sm">
        <span class="">
          <span class="text-gray-500">
            Seller:
            <span class="text-gray-100"><%= @offer.listing.user_game_item.user.username %></span>
          </span>
        </span>
        <span class="text-zinc-600 mx-1">|</span>
        <span class="font-mono text-sm px-[2px] py-[1px] text-zinc-600">
          <%= relative_ts(@offer.inserted_at) %> | <.offer_status status={@offer.status} />
        </span>
      </div>
    </article>
    """
  end

  defp offer_status(%{status: :active} = assigns) do
    ~H|<span class="bg-blue-500/50 py-[2px] px-1 text-white"><%= humanize_offer_status(@status) %></span>|
  end

  defp offer_status(%{status: :accepted_by_seller} = assigns) do
    ~H|<span class="bg-blue-700/50 py-[2px] px-1 text-white"><%= humanize_offer_status(@status) %></span>|
  end

  defp offer_status(%{status: :declined_by_seller} = assigns) do
    ~H|<span class="bg-red-600/50 py-[3px] px-1 text-white"><%= humanize_offer_status(@status) %></span>|
  end

  defp offer_status(assigns) do
    ~H"<%= humanize_offer_status(@status) %>"
  end

  defp buyout?(%{listing: listing} = offer) do
    listing.price_gold == offer.offer_gold_amount &&
      listing.price_golden_keys == offer.offer_golden_keys_amount
  end

  defp relative_ts(dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> Dakka.Cldr.DateTime.Relative.to_string!()
  end

  defdelegate humanize_offer_status(status), to: Dakka.Market.ListingOffer, as: :humanize_status
end
