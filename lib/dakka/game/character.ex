defmodule Dakka.Game.Character do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dakka.Accounts.User

  schema "users_game_characters" do
    field :name, :string
    field :last_trade_at, :naive_datetime
    field :removal_scheduled_at, :naive_datetime

    belongs_to :user, User
  end

  def changeset(character, attrs, opts \\ []) do
    character
    |> cast(attrs, [:name, :last_trade_at, :removal_scheduled_at])
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
end
