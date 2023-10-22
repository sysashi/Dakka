defmodule Dakka.Market.ListingOffer do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dakka.Market.Listing
  alias Dakka.Accounts.User

  @statuses [
    :active,
    :accepted_by_seller,
    :declined_by_seller,
    :declined_listing_sold,
    :declined_listing_expired,
    :declined_listing_deleted,
    :declined_listing_changed,
    :cancelled_by_buyer,
    :expired
  ]

  schema "market_listings_offers" do
    field :offer_gold_amount, :integer
    field :offer_golden_keys_amount, :integer
    field :expires_at, :utc_datetime

    field :status, Ecto.Enum, values: @statuses, default: :active

    belongs_to :user, User
    belongs_to :listing, Listing

    timestamps()
  end

  def changeset(offer, attrs \\ %{}) do
    offer
    |> cast(attrs, [:offer_gold_amount, :offer_golden_keys_amount])
    |> validate_required([])
    |> check_constraint(:offer_gold_amount, name: :offer_amount_set, message: "empty offer")
    |> unique_constraint(:listing,
      name: :one_active_listing_offer,
      message: "active offer already exists for this listing"
    )
    |> unique_constraint(:listing,
      name: :one_accepted_listing_offer,
      message: "accepted offer already exists for this listing"
    )
  end

  def change_status(offer, status) do
    change(offer, %{status: status})
  end

  def options() do
    Enum.map(@statuses, &{humanize_status(&1), &1})
  end

  def humanize_status(:active), do: "Active"
  def humanize_status(:accepted_by_seller), do: "Accepted"
  def humanize_status(:declined_by_seller), do: "Declined"
  def humanize_status(:declined_listing_sold), do: "Item Sold"
  def humanize_status(:declined_listing_expired), do: "Listing Expired"
  def humanize_status(:declined_listing_deleted), do: "Listing Removed"
  def humanize_status(:declined_listing_changed), do: "Listing Changed"
  def humanize_status(:cancelled_by_buyer), do: "Cancelled"
  def humanize_status(:expired), do: "Offer Expired"
end
