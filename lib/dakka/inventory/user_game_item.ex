defmodule Dakka.Inventory.UserGameItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dakka.Accounts.User
  alias Dakka.Game.ItemBase
  alias Dakka.Inventory.UserGameItemMod
  alias Dakka.Market.Listing

  schema "users_game_items" do
    field :quantity, :integer, default: 1
    field :position, :integer
    field :deleted_at, :naive_datetime_usec

    belongs_to :item_base, ItemBase
    belongs_to :user, User

    has_many :mods, UserGameItemMod
    has_many :implicit_mods, UserGameItemMod, where: [mod_type: :implicit]
    has_many :explicit_mods, UserGameItemMod, where: [mod_type: :explicit]

    has_one :listing, Listing, where: [deleted_at: nil]

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:quantity])
  end

  def delete(item) do
    change(item, %{deleted_at: NaiveDateTime.utc_now()})
  end
end
