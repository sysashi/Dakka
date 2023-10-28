defmodule Dakka.Inventory do
  import Ecto.Query, warn: false

  alias Dakka.Game
  alias Dakka.Game.ItemBaseMod
  alias Dakka.Inventory.Events.{UserItemCreated, UserItemDeleted}
  alias Dakka.Inventory.{UserGameItem, UserGameItemMod}
  alias Dakka.Repo
  alias Dakka.Scope

  alias Ecto.Changeset
  alias Ecto.Multi

  ## Pusub

  @pubsub Dakka.PubSub

  def topic(%Scope{} = scope), do: "user_inventory:#{scope.current_user.id}"

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(@pubsub, topic(topic))
  end

  defp broadcast(topic, event) do
    Phoenix.PubSub.broadcast(@pubsub, topic(topic), {__MODULE__, event})
  end

  ## User Items

  @user_item_strings_paths [
    [:item_base, :strings],
    [:item_base, :properties, :item_mod, :strings],
    [:item_base, :properties, :item_mod_values, :strings],
    [:implicit_mods, :item_mod, :strings],
    [:explicit_mods, :item_mod, :strings]
  ]

  def get_user_item!(%Scope{} = scope, id) do
    item =
      UserGameItem
      |> where(id: ^id)
      |> where(user_id: ^scope.current_user_id)
      |> where(deleted: false)
      |> preload(^item_preloads())
      |> preload(:listing)
      |> Repo.one!()

    group_strings(item)
  end

  def find_user_item(%Scope{} = scope, id) do
    query =
      UserGameItem
      |> where(id: ^id)
      |> where(user_id: ^scope.current_user_id)
      |> where(deleted: false)
      |> preload(^item_preloads())
      |> preload(:listing)

    with {:ok, item} <- Repo.find(query) do
      {:ok, group_strings(item)}
    end
  end

  def list_user_items(%Scope{} = scope) do
    UserGameItem
    |> where(deleted: false)
    |> where(user_id: ^scope.current_user_id)
    |> order_by(asc: :position, desc: :inserted_at)
    |> preload(^item_preloads())
    |> preload(:listing)
    |> Repo.all()
    |> Enum.map(&Game.group_translation_strings(&1, @user_item_strings_paths))
  end

  def user_item_preload_query() do
    UserGameItem
    |> preload(^item_preloads())
  end

  def group_strings(item) do
    Game.group_translation_strings(item, @user_item_strings_paths)
  end

  def item_preloads() do
    [
      [
        item_base: [
          :item_rarity,
          [strings: :language],
          properties: [
            item_mod: [strings: :language],
            item_mod_values: [strings: :language]
          ]
        ]
      ],
      [
        implicit_mods: [
          item_mod: [strings: :language]
        ]
      ],
      [
        explicit_mods: [
          item_mod: [strings: :language]
        ]
      ]
    ]
  end

  def build_user_item(%Scope{current_user: user}, item_base) do
    %UserGameItem{user_id: user.id, item_base: item_base, item_base_id: item_base.id}
  end

  def user_item_base_changeset(user_item, item_base, label_fun) do
    user_item
    |> Changeset.change()
    |> Changeset.put_assoc(:item_base, item_base)
    |> Changeset.put_assoc(:explicit_mods, [])
    |> Changeset.put_assoc(
      :implicit_mods,
      Enum.map(item_base.implicit_mods, &convert_to_user_item_mod(&1, label_fun))
    )
  end

  def user_item_preview(%Changeset{} = changeset), do: Changeset.apply_changes(changeset)

  def create_user_item(scope, user_item, params) do
    changeset = change_user_item(user_item, params)

    case Repo.insert(changeset) do
      {:ok, item} ->
        item =
          item
          |> Repo.preload([
            :listing,
            implicit_mods: [item_mod: [strings: :language]],
            explicit_mods: [item_mod: [strings: :language]]
          ])
          |> Game.group_translation_strings([
            [:implicit_mods, :item_mod, :strings],
            [:explicit_mods, :item_mod, :strings]
          ])

        broadcast(
          scope,
          %UserItemCreated{user_item: item}
        )

        {:ok, item}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def change_user_item(user_item, params) do
    user_item
    |> Changeset.cast(params, [])
    |> Changeset.cast_assoc(:implicit_mods,
      sort_param: :impl_sort,
      drop_param: :impl_drop
    )
    |> Changeset.cast_assoc(:explicit_mods,
      sort_param: :expl_sort,
      drop_param: :expl_drop
    )
    |> validate_explicit_mods_length(user_item.item_base.item_rarity.slug)
  end

  @max_mods_by_rarity %{
    "junk" => 0,
    "poor" => 0,
    "common" => 0,
    "uncommon" => 1,
    "rare" => 2,
    "epic" => 3,
    "legendary" => 4,
    "unique" => 5
  }

  def validate_explicit_mods_length(changeset, rarity) do
    Changeset.validate_length(changeset, :explicit_mods,
      max: @max_mods_by_rarity[rarity],
      message: "should have %{count} mod(s)"
    )
  end

  def add_mod(changeset, mod, item_base \\ nil) do
    {type, mods} =
      case mod do
        %{"mod_type" => "implicit"} ->
          {:implicit, :implicit_mods}

        %{"mod_type" => "explicit"} ->
          {:explicit, :explicit_mods}
      end

    params = %{
      value: mod["value"],
      label: mod["localized_string"],
      item_mod_id: mod["id"],
      mod_type: type,
      value_type: mod["value_type"]
    }

    mod = UserGameItemMod.changeset(%UserGameItemMod{}, params)

    changeset = Changeset.update_change(changeset, mods, fn mods -> mods ++ [mod] end)

    # TODO FIX
    if item_base do
      validate_explicit_mods_length(changeset, item_base.item_rarity.slug)
    else
      changeset
    end
  end

  defp convert_to_user_item_mod(%ItemBaseMod{} = item_base_mod, label_fun) do
    value_float =
      if item_base_mod.item_mod.value_type == :percentage and item_base_mod.min_value do
        item_base_mod.min_value / 10
      end

    %UserGameItemMod{
      mod_type: item_base_mod.mod_type,
      item_mod_id: item_base_mod.item_mod_id,
      label: label_fun.(item_base_mod.item_mod.strings),
      value: item_base_mod.min_value,
      value_type: item_base_mod.item_mod.value_type,
      value_float: value_float
    }
  end

  def delete_user_item(%Scope{} = scope, item_id) do
    item =
      UserGameItem
      |> where(id: ^item_id)
      |> where(user_id: ^scope.current_user_id)
      |> Repo.one!()

    changeset = UserGameItem.delete(item)

    multi =
      Multi.new()
      |> Multi.update(:item, changeset)
      |> Multi.merge(&Dakka.Market.delete_item_listings_multi(&1.item))

    case Repo.transaction(multi) do
      {:ok, %{item: item, deleted_listings: {_, listings}}} ->
        broadcast(scope, %UserItemDeleted{user_item: item})

        for listing <- listings do
          market_event = %Dakka.Market.Events.ListingDeleted{listing: listing}
          Dakka.Market.broadcast!(scope, market_event)
          Dakka.Market.Public.broadcast(market_event)
        end

        {:ok, item}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  ## Utils

  def generate_random_item() do
    item_mod_ids =
      Game.ItemMod
      |> where([im], im.value_type in [:integer, :percentage])
      |> select([im], im.id)
      |> Repo.all()

    item_base_count = Repo.aggregate(Game.ItemBase, :count, :id)
    random_row = Enum.random(0..(item_base_count - 1))

    item_base =
      Game.ItemBase
      |> offset(^random_row)
      |> preload([:item_rarity, implicit_mods: :item_mod])
      |> limit(1)
      |> Repo.one!()

    mods_limit = @max_mods_by_rarity[item_base.item_rarity.slug]
    mods_count = Enum.random(0..mods_limit)

    random_mods =
      Game.ItemMod
      |> where([im], im.value_type in [:integer, :percentage])
      |> where([im], im.id in ^Enum.take_random(item_mod_ids, mods_count))
      |> Repo.all()

    changeset =
      %UserGameItem{}
      |> Changeset.change()
      |> Changeset.put_assoc(:item_base, item_base)
      |> Changeset.put_assoc(
        :implicit_mods,
        Enum.map(item_base.implicit_mods, &to_random_user_mod(&1, :implicit))
      )

    if "armor" in item_base.labels or "weapon" in item_base.labels do
      Changeset.put_assoc(
        changeset,
        :explicit_mods,
        Enum.map(random_mods, &to_random_user_mod(&1, :explicit))
      )
    else
      changeset
    end
  end

  defp to_random_user_mod(item_base_mod_or_item_mod, mod_type) do
    {mod_id, value, value_type} =
      case item_base_mod_or_item_mod do
        %ItemBaseMod{} = base_mod ->
          %{min_value: min, max_value: max} = base_mod

          value =
            cond do
              min && max ->
                Enum.random(min..max)

              min || max ->
                min || max

              true ->
                random_mod_value(base_mod.item_mod.value_type)
            end

          {base_mod.item_mod_id, value, base_mod.item_mod.value_type}

        %Game.ItemMod{} = item_mod ->
          {item_mod.id, random_mod_value(item_mod.value_type), item_mod.value_type}
      end

    %UserGameItemMod{
      mod_type: mod_type,
      item_mod_id: mod_id,
      value: value,
      value_type: value_type
    }
  end

  defp random_mod_value(type) do
    base = Enum.random(1..5)

    if type == :percentage do
      base * 10
    else
      base
    end
  end
end
