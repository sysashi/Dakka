defmodule Dndah.Game.ItemModValue do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dndah.Game.{
    ItemMod,
    ItemModValue,
    TranslationString
  }

  schema "game_item_mods_values" do
    field :slug, :string
    field :in_game_id, :string

    belongs_to :item_mod, ItemMod
    has_many :strings, TranslationString
  end

  def changeset(item_mod_value, attrs \\ %{}) do
    item_mod_value
    |> cast(attrs, [:slug, :in_game_id])
    |> validate_required(:slug)
    |> unique_constraint(:slug)
  end

  def build(item_mod, attrs) do
    changeset(%ItemModValue{item_mod_id: item_mod.id}, attrs)
  end
end
