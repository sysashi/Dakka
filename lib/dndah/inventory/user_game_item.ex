defmodule Dndah.Inventory.UserGameItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dndah.Accounts.User
  alias Dndah.Game.ItemBase
  alias Dndah.Inventory.UserGameItemMod
  alias Dndah.Market.Listing

  schema "users_game_items" do
    field :quantity, :integer, default: 1
    field :position, :integer

    belongs_to :item_base, ItemBase
    belongs_to :user, User

    has_many :mods, UserGameItemMod
    has_many :implicit_mods, UserGameItemMod, where: [mod_type: :implicit]
    has_many :explicit_mods, UserGameItemMod, where: [mod_type: :explicit]

    has_one :listing, Listing, where: [deleted: false]
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:quantity])
  end
end
