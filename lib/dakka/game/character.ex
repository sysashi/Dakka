defmodule Dakka.Game.Character do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dakka.Accounts.User

  @classes ~w(barbarian bard cleric druid fighter ranger rogue warlock wizard)a

  schema "users_game_characters" do
    field :name, :string
    field :class, Ecto.Enum, values: @classes
    field :last_trade_at, :naive_datetime_usec
    field :removal_scheduled_at, :utc_datetime_usec

    belongs_to :user, User

    timestamps()
  end

  def changeset(character, attrs, opts \\ []) do
    character
    |> cast(attrs, [:name, :class])
    |> validate_required(:name)
    |> validate_length(:name, min: 1)
    |> maybe_validate_unique_name(opts)
  end

  defp maybe_validate_unique_name(changeset, opts) do
    if Keyword.get(opts, :validate_name, true) do
      changeset
      |> unsafe_validate_unique(:name, Dakka.Repo)
      |> unique_constraint(:name)
    else
      changeset
    end
  end

  def class_options() do
    Enum.map(@classes, &{String.capitalize("#{&1}"), &1})
  end
end
