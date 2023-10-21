defmodule Dndah.Game.ItemBaseModValue do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dndah.Game.{
    ItemBaseMod,
    ItemBaseModValue,
    ItemModValue
  }

  schema "game_item_bases_mod_values" do
    belongs_to :item_base_mod, ItemBaseMod
    belongs_to :item_mod_value, ItemModValue
  end

  def changeset(bmv, attrs \\ %{}) do
    bmv
    |> cast(attrs, [:item_base_mod_id, :item_mod_value_id])
    |> validate_required([:item_base_mod_id, :item_mod_value_id])
    |> unique_constraint([:item_base_mod_id, :item_mod_value_id])
  end

  def build(attrs) do
    changeset(%ItemBaseModValue{}, attrs)
  end
end
