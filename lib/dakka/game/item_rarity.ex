defmodule Dakka.Game.ItemRarity do
  @moduledoc """
  Maps in-game rarity code to app rarity
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "game_item_rarities" do
    field :slug, :string
    field :rarity_rank, :integer
    field :in_game_id, :string
  end

  def changeset(lang, attrs \\ %{}) do
    lang
    |> cast(attrs, [:slug, :rarity_rank, :in_game_code])
    |> validate_required([:slug, :rarity_rank])
    |> unique_constraint(:slug)
    |> unique_constraint(:rarity_rank)
  end
end
