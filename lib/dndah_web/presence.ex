defmodule DndahWeb.Presence do
  @pubsub Dndah.PubSub

  use Phoenix.Presence,
    otp_app: :dndah,
    pubsub_server: @pubsub

  def init(_opts) do
    # user-land state
    {:ok, %{}}
  end

  def subscribe(offer) do
    Phoenix.PubSub.subscribe(@pubsub, topic(offer))
  end

  def track_trade(offer, user) do
    track(self(), "proxy:" <> topic(offer), user.id, %{})
  end

  def topic(offer), do: "offer_presence:#{offer.id}"

  def list_trade_users(offer) do
    list("proxy:" <> topic(offer))
  end

  def fetch(_topic, presences) do
    users =
      presences
      |> Map.keys()
      |> Dndah.Accounts.get_users_map()

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
