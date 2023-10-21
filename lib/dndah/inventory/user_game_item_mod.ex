defmodule Dndah.Inventory.UserGameItemMod do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dndah.Inventory.UserGameItem

  alias Dndah.Game.{
    ItemMod
  }

  schema "users_game_items_mods" do
    field :value, :integer
    field :mod_type, Ecto.Enum, values: Dndah.Game.ItemBaseMod.mod_types()

    belongs_to :item_mod, ItemMod
    belongs_to :user_game_item, UserGameItem

    field :label, :string, virtual: true

    field :value_type, Ecto.Enum,
      values: [:integer, :percentage, :predefined_value],
      virtual: true

    field :value_float, :float, virtual: true, default: 0.0
  end

  def changeset(item_mod, attrs \\ %{}) do
    item_mod
    |> cast(attrs, [:mod_type, :value, :item_mod_id, :label, :value_type, :value_float])
    |> float_to_int()
    |> validate_required([:mod_type, :value, :item_mod_id])
    |> unique_constraint([:mod_type, :user_game_item_id, :item_mod_id],
      name: :unique_user_game_item_mod_per_type,
      message: "item already has this mod"
    )
  end

  def float_to_int(changeset) do
    type = get_field(changeset, :value_type)

    with :percentage <- type,
         {:ok, float} <- fetch_change(changeset, :value_float) do
      value =
        float
        |> Decimal.from_float()
        |> Decimal.mult(10)
        |> Decimal.to_integer()

      put_change(changeset, :value, value)
    else
      _ ->
        changeset
    end
  end
end
