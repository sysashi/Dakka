defmodule Dakka.Market.Public do
  @moduledoc false

  @pubsub Dakka.PubSub

  def subscribe() do
    Phoenix.PubSub.subscribe(@pubsub, topic())
  end

  def broadcast(event) do
    Phoenix.PubSub.broadcast(@pubsub, topic(), {__MODULE__, event})
  end

  defp topic(), do: "public_market_events"
end
