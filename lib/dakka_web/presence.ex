defmodule DakkaWeb.Presence do
  @pubsub Dakka.PubSub

  alias Dakka.Scope
  alias Dakka.Accounts.User
  alias Dakka.Market.ListingOffer

  use Phoenix.Presence,
    otp_app: :dakka,
    pubsub_server: @pubsub

  def init(_opts) do
    # user-land state
    {:ok, %{}}
  end

  def subscribe(%ListingOffer{} = offer) do
    Phoenix.PubSub.subscribe(@pubsub, topic(offer))
  end

  def subscribe(:market) do
    Phoenix.PubSub.subscribe(@pubsub, topic(:market))
  end

  def track_trade(%ListingOffer{} = offer, %User{} = user) do
    track(self(), "proxy:" <> topic(offer), user.id, %{})
  end

  def track(%Scope{current_user: %User{} = user}) do
    track(self(), "proxy:" <> topic(:market), user.id, %{})
  end

  def topic(:market), do: "market"
  def topic(%ListingOffer{} = offer), do: "offer_presence:#{offer.id}"

  def list_trade_users(offer) do
    list("proxy:" <> topic(offer))
  end

  def list_market_users() do
    list("proxy:" <> topic(:market))
  end

  def user_online?(topic, user_id) do
    Enum.any?(get_by_key("proxy:" <> topic(topic), user_id))
  end

  def fetch(_topic, presences) do
    users =
      presences
      |> Map.keys()
      |> Dakka.Accounts.get_users_map()

    for {key, %{metas: metas}} <- presences, into: %{} do
      {key, %{metas: metas, user: users[String.to_integer(key)]}}
    end
  end

  def handle_metas("proxy:" <> topic, %{joins: joins, leaves: leaves}, presences, state) do
    # fetch existing presence information for the joined users and broadcast the
    # event to all subscribers
    for {user_id, presence} <- joins do
      user_data = %{user: presence.user, metas: Map.fetch!(presences, user_id)}
      msg = {__MODULE__, {:user_joined, user_data}}
      Phoenix.PubSub.local_broadcast(@pubsub, topic, msg)
    end

    # fetch existing presence information for the left users and broadcast the
    # event to all subscribers
    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{user: presence.user, metas: metas}
      msg = {__MODULE__, {:user_left, user_data}}
      Phoenix.PubSub.local_broadcast(@pubsub, topic, msg)
    end

    {:ok, state}
  end
end
