defmodule Dakka.Game.ItemMod do
  @moduledoc """
  Schema for game item mods
  Examples: additional_physical_damage, will, require_class, weapon_type
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dakka.Game.{
    ItemMod,
    ItemModValue,
    TranslationString
  }

  schema "game_item_mods" do
    field :slug, :string
    field :in_game_id
    field :special, :boolean, default: false
    field :value_type, Ecto.Enum, values: [:integer, :percentage, :predefined_value]
    field :max_value, :integer
    field :min_value, :integer

    has_many :values, ItemModValue
    has_many :strings, TranslationString
  end

  def changeset(item_mod, attrs \\ %{}) do
    item_mod
    |> cast(attrs, [:slug, :value_type, :special, :max_value, :min_value, :in_game_id])
    |> validate_required([:slug, :value_type])
    |> unique_constraint(:slug)
  end

  def build(attrs) do
    changeset(%ItemMod{}, attrs)
  end
end
