defmodule Dakka.Market.Listing do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dakka.Inventory.UserGameItem
  alias Dakka.Market.ListingOffer

  schema "market_listings" do
    field :price_gold, :integer
    field :price_golden_keys, :integer
    field :open_for_offers, :boolean, default: false
    field :expires_at, :utc_datetime
    field :status, Ecto.Enum, values: [:active, :sold, :expired], default: :active
    field :deleted_at, :naive_datetime_usec

    field :relist, :boolean, default: false, virtual: true

    belongs_to :user_game_item, UserGameItem
    has_one :seller, through: [:user_game_item, :user]
    has_many :offers, ListingOffer

    timestamps()
  end

  def changeset(listing, attrs \\ %{}) do
    listing
    |> cast(attrs, [:price_gold, :price_golden_keys, :open_for_offers, :deleted_at, :relist])
    |> validate_required([:open_for_offers])
    |> validate_number(:price_gold, greater_than: 0)
    |> validate_number(:price_golden_keys, greater_than: 0)
    |> price_or_offers()
    |> maybe_relist()
    |> unique_constraint(:user_game_item_id,
      name: :market_listings_unique_active_item_listing_idx,
      message: "item has been already listed"
    )
    |> check_constraint(:price_gold,
      name: :price_set_or_open_for_offers,
      message: "either price must be set or open for offers flag"
    )
    |> check_constraint(:price_gold,
      name: :positive_price,
      message: "price must be positive"
    )
  end

  def delete(listing) do
    change(listing, %{deleted_at: NaiveDateTime.utc_now()})
  end

  def mark_sold(listing) do
    change(listing, %{status: :sold})
  end

  def price_or_offers(changeset) do
    case fetch_field(changeset, :open_for_offers) do
      {_, true} ->
        changeset

      _ ->
        gold = get_field(changeset, :price_gold)
        keys = get_field(changeset, :price_golden_keys)

        if gold || keys do
          changeset
        else
          add_error(changeset, :price_gold, "either price or open for offers flag must be set")
        end
    end
  end

  defp maybe_relist(changeset) do
    case fetch_field(changeset, :relist) do
      {_, true} ->
        put_change(changeset, :status, :active)

      _ ->
        changeset
    end
  end
end
