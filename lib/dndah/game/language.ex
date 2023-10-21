defmodule Dndah.Game.Language do
  @moduledoc """
  Game/Item supported langugage
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "game_languages" do
    field :name, :string
    field :code, Ecto.Enum, values: [:en, :zh_hans, :ja]
    field :eng_label, :string
  end

  def changeset(lang, attrs \\ %{}) do
    lang
    |> cast(attrs, [:name, :code, :eng_label])
    |> validate_required([:name, :code, :eng_label])
    |> unique_constraint(:code)
  end

  def to_code("en"), do: :en
  def to_code("ja"), do: :ja
  def to_code("zh-Hans"), do: :zh_hans
  def to_code(code) when code in [:en, :ja, :zh_hans], do: code

  def to_code(code) do
    raise ArgumentError, "Unknown language #{inspect(code)}"
  end
end
