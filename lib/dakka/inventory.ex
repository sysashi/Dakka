defmodule Dakka.Inventory do
  import Ecto.Query, warn: false

  alias Dakka.Repo
  alias Dakka.Accounts.User
  alias Dakka.Inventory.{UserGameItem, UserGameItemMod}
  alias Dakka.Game
  alias Dakka.Scope
  alias Dakka.Game.{ItemBase, ItemBaseMod}

  alias Dakka.Inventory.Events.{
    UserItemCreated
  }

  alias Ecto.Changeset

  ## Pusub

  @pubsub Dakka.PubSub

  def topic(user_id), do: "user_inventory:#{user_id}"

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

  def get_user_item!(user, id) do
    item =
      UserGameItem
      |> where(id: ^id)
      |> where(user_id: ^user.id)
      |> preload(^item_preloads())
      |> preload(:listing)
      |> Repo.one!()

    group_strings(item)
  end

  def list_user_items(user) do
    UserGameItem
    |> where(user_id: ^user.id)
    |> order_by(asc: :position)
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

  def build_user_item(user, item_base) do
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

  def create_user_item(user_item, params) do
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
          item.user_id,
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

  # def add_mod(changeset, params) do
  #   changeset
  #   |> Changeset.cast(wrap_params(params), [])
  #   |> Changeset.cast_assoc(:explicit_mods)
  #   |> Changeset.cast_assoc(:implicit_mods)
  # end

  # defp wrap_params(%{"mod_type" => "implicit"} = params), do: %{"implicit_mods" => [params]}
  # defp wrap_params(%{"mod_type" => "explicit"} = params), do: %{"explicit_mods" => [params]}

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
    %UserGameItemMod{
      mod_type: item_base_mod.mod_type,
      item_mod_id: item_base_mod.item_mod_id,
      label: label_fun.(item_base_mod.item_mod.strings),
      value: item_base_mod.min_value,
      value_type: item_base_mod.item_mod.value_type
    }
  end
end
