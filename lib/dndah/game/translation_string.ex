defmodule Dndah.Game.TranslationString do
  @moduledoc """
  Key - Value records that hold translated value for various game items, mods and mod values
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dndah.Game.{
    ItemBase,
    ItemMod,
    ItemModValue,
    Language,
    TranslationString
  }

  schema "game_translation_strings" do
    # field :group, :string
    # field :entity_slug, :string
    field :key, Ecto.Enum, values: [:name, :desc, :flavor_text, :unique_effect]
    field :value, :string

    # belongs_to :item_rarity, ItemRarity
    belongs_to :language, Language
    belongs_to :item_base, ItemBase
    belongs_to :item_mod, ItemMod
    belongs_to :item_mod_value, ItemModValue
  end

  def changeset(gts, attrs \\ %{}) do
    gts
    |> cast(attrs, [
      # :group,
      # :entity_slug,
      :key,
      :value,
      # :item_rarity_id,
      :language_id,
      :item_base_id,
      :item_mod_id,
      :item_mod_value_id
    ])
    |> validate_required([:key, :value, :language_id])
    |> unique_constraint(:value, name: :unique_game_translation_string)
  end

  def build(attrs) do
    changeset(%TranslationString{}, attrs)
  end
end
