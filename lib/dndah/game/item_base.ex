defmodule Dndah.Game.ItemBase do
  @moduledoc """
  Schema for in-game item base
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dndah.Game.{
    ItemBase,
    ItemBaseMod,
    ItemRarity,
    TranslationString
  }

  schema "game_item_bases" do
    field :slug, :string
    field :in_game_id, :string
    field :min_explicit_mods, :integer
    field :max_explicit_mods, :integer
    field :icon_path, :string
    field :original_icon_file, :string
    field :labels, {:array, :string}, default: []

    belongs_to :item_rarity, ItemRarity

    has_many :mods, ItemBaseMod

    has_many :implicit_mods, ItemBaseMod,
      where: [mod_type: :implicit],
      preload_order: [asc: :order]

    has_many :explicit_mods, ItemBaseMod, where: [mod_type: :explicit]
    has_many :properties, ItemBaseMod, where: [mod_type: :property]

    has_many :strings, TranslationString
  end

  def changeset(item_base, attrs \\ %{}) do
    item_base
    |> cast(attrs, [
      :slug,
      :in_game_id,
      :min_explicit_mods,
      :max_explicit_mods,
      :labels,
      :icon_path,
      :original_icon_file
    ])
    |> validate_required(:slug)
    |> unique_constraint([:slug, :item_rarity_id])
  end

  def build(rarity_id, attrs) do
    changeset(%ItemBase{item_rarity_id: rarity_id}, attrs)
  end

  def sort_properties(properties) do
    properties
    |> Enum.map(&{&1.item_mod.slug, &1})
    |> Enum.sort_by(&elem(&1, 0))
  end

  def compare("required_class"), do: 0
  def compare("slot_type"), do: 1
  def compare("utility_type"), do: 2
  def compare("hand_type"), do: 3
  def compare("weapon_type"), do: 4
  def compare("armor_type"), do: 5
end
