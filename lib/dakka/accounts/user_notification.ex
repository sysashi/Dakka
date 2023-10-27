defmodule Dakka.Accounts.UserNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dakka.Accounts.User
  alias Dakka.Accounts.UserNotification

  alias Dakka.Market.{
    Listing,
    ListingOffer
  }

  @actions [
    # send to buyer
    :offer_accepted,
    :offer_declined,

    # send to seller
    :offer_cancelled,
    :offer_created
  ]

  schema "users_notifications" do
    field :object, :string

    field :action, Ecto.Enum, values: @actions

    belongs_to :actor, User

    field :meta, :map
    field :read_at, :naive_datetime

    # object refs
    belongs_to :listing, Listing
    belongs_to :offer, ListingOffer

    # target
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  def actions(), do: @actions

  def to_browser_notification(%UserNotification{} = notif, lang \\ :en) do
    tag =
      if notif.action in [:offer_created, :offer_cancelled] do
        "listing:#{notif.offer.listing_id}"
      else
        ""
      end

    %{
      title: action_title(notif.action),
      body: notification_body(notif, lang),
      tag: tag
    }
  end

  def build(%User{} = target, object, action, actor) do
    %UserNotification{}
    |> change(%{action: action})
    |> put_assoc(:user, target)
    |> put_object(object)
    |> put_actor(actor)
  end

  defp put_object(changeset, %Listing{} = listing) do
    changeset
    |> put_assoc(:listing, listing)
    |> put_change(:object, "listing")
  end

  defp put_object(changeset, %ListingOffer{} = offer) do
    changeset
    |> put_assoc(:offer, offer)
    |> put_change(:object, "offer")
  end

  defp put_actor(changeset, %User{} = actor), do: put_assoc(changeset, :actor, actor)
  defp put_actor(changeset, _), do: changeset

  defp action_title(:offer_accepted), do: "Your offer was accepted"
  defp action_title(:offer_declined), do: "Your offer was declined"
  defp action_title(:offer_created), do: "You've got a new offer"
  defp action_title(:offer_cancelled), do: "Offer was canceled"

  defp notification_body(%{action: :offer_accepted, offer: offer, actor: actor}, lang) do
    item_base = offer.listing.user_game_item.item_base
    "#{format_actor(actor)} accepted offer for #{format_item_base(item_base, lang)}"
  end

  defp notification_body(%{action: :offer_declined, offer: offer, actor: actor}, lang) do
    item_base = offer.listing.user_game_item.item_base
    "#{format_actor(actor)} declined your offer for #{format_item_base(item_base, lang)}"
  end

  defp notification_body(%{action: :offer_cancelled, offer: offer, actor: actor}, lang) do
    item_base = offer.listing.user_game_item.item_base
    "#{format_actor(actor)} cancelled offer for #{format_item_base(item_base, lang)}"
  end

  defp notification_body(%{action: :offer_created, offer: offer, actor: actor}, lang) do
    buyout? =
      offer.listing.price_gold == offer.offer_gold_amount &&
        offer.listing.price_golden_keys == offer.offer_golden_keys_amount

    item_base = offer.listing.user_game_item.item_base
    action = if buyout?, do: "wants to buy", else: "created an offer for"

    "#{format_actor(actor)} #{action} #{format_item_base(item_base, lang)}"
  end

  defp notification_body(_, _), do: ""

  defp format_actor(%User{username: username}), do: username
  defp format_actor(_), do: ""

  defp format_item_base(item_base, lang) do
    name = string(item_base, :name, lang)
    rarity = item_base.item_rarity.slug

    "#{name} (#{rarity})"
  end

  defp string(%{strings: strings, slug: slug}, key, lang) do
    strings[key][lang] || strings[key][:en] || slug
  end
end
