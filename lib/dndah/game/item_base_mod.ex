defmodule Dndah.Game.ItemBaseMod do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dndah.Game.{
    ItemBase,
    ItemBaseMod,
    ItemBaseModValue,
    ItemMod
  }

  @mod_types [:implicit, :explicit, :property]

  def mod_types(), do: @mod_types

  schema "game_item_bases_mods" do
    field :mod_type, Ecto.Enum, values: @mod_types
    field :value, :integer
    field :max_value, :integer
    field :min_value, :integer

    belongs_to :item_mod, ItemMod
    belongs_to :item_base, ItemBase

    has_many :item_base_mod_values, ItemBaseModValue
    has_many :item_mod_values, through: [:item_base_mod_values, :item_mod_value]
  end

  def changeset(item_base_mod, attrs \\ %{}) do
    item_base_mod
    |> cast(attrs, [:mod_type, :value, :max_value, :min_value, :item_mod_id])
    |> validate_required(:mod_type)
  end

  def build(item_base, attrs) do
    changeset(%ItemBaseMod{item_base_id: item_base.id}, attrs)
  end

  def compare(:implicit, _), do: :gt
  def compare(:explicit, :implicit), do: :lt
  def compare(:explicit, _), do: :gt
  def compare(:property, _), do: :lt
end
