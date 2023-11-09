defmodule Dakka.ItemFilters do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__.{NumMod, PropMod, CompOps}

  @primary_key false

  @all_rarities ~w(junk poor common uncommon rare epic legendary unique)
  @all_rarities_set MapSet.new(@all_rarities)

  embedded_schema do
    field :item_base, :string
    field :item_base_slug, :string

    field :rarities, {:array, :string},
      default: ~w(junk poor common uncommon rare epic legendary unique)

    embeds_one :price, Price, on_replace: :delete do
      field :gold, :integer
      field :gold_op, Ecto.Enum, values: CompOps.values(), default: :lt_or_eq
      field :golden_keys, :integer
      field :golden_keys_op, Ecto.Enum, values: CompOps.values(), default: :lt_or_eq
      field :open_for_offers, :boolean, default: true
    end

    embeds_many :implicit_mods, NumMod, on_replace: :delete
    embeds_many :explicit_mods, NumMod, on_replace: :delete
    embeds_many :properties, PropMod, on_replace: :delete
  end

  def base_filters() do
    {:ok, filters} = to_filters(build())
    filters
  end

  def build(attrs \\ %{}) do
    changeset(%__MODULE__{price: %__MODULE__.Price{}}, attrs)
  end

  def change(filters, attrs) do
    changeset(filters, attrs)
  end

  def add_mod(changeset, params, :implicit) do
    mods = get_embed(changeset, :implicit_mods)
    mod_changeset = num_mod_changeset(%NumMod{}, params)
    put_embed(changeset, :implicit_mods, mods ++ [mod_changeset])
  end

  def add_mod(changeset, params, :explicit) do
    mods = get_embed(changeset, :explicit_mods)
    mod_changeset = num_mod_changeset(%NumMod{}, params)
    put_embed(changeset, :explicit_mods, mods ++ [mod_changeset])
  end

  def add_mod(changeset, params, :property) do
    mods = get_embed(changeset, :properties)
    mod_changeset = prop_mod_changeset(%PropMod{}, params)
    put_embed(changeset, :properties, mods ++ [mod_changeset])
  end

  def add_item_base(changeset, params) do
    changeset(changeset, params)
  end

  def changeset(filters, attrs \\ %{}) do
    filters
    |> cast(attrs, [:item_base, :item_base_slug, :rarities], force_changes: true)
    |> maybe_clear_item_base()
    |> cast_embed(:implicit_mods,
      sort_param: :impl_sort,
      drop_param: :impl_drop,
      with: &num_mod_changeset/2
    )
    |> cast_embed(:explicit_mods,
      sort_param: :expl_sort,
      drop_param: :expl_drop,
      with: &num_mod_changeset/2
    )
    |> cast_embed(:properties,
      sort_param: :prop_sort,
      drop_param: :prop_drop,
      with: &prop_mod_changeset/2
    )
    |> cast_embed(:price, with: &price_changeset/2)
  end

  defp maybe_clear_item_base(changeset) do
    with {:ok, nil} <- fetch_change(changeset, :item_base_slug) do
      force_change(changeset, :item_base, nil)
    else
      _ ->
        changeset
    end
  end

  defp num_mod_changeset(mod, attrs) do
    mod
    |> cast(attrs, [:slug, :value, :value_float, :value_type, :label, :op])
    |> Dakka.Inventory.UserGameItemMod.float_to_int()
  end

  defp prop_mod_changeset(mod, attrs) do
    mod
    |> cast(attrs, [:slug, :label, :prop])
  end

  defp price_changeset(price, attrs) do
    price
    |> cast(attrs, [:gold, :gold_op, :golden_keys, :golden_keys_op, :open_for_offers])
    |> validate_number(:gold, greater_than: 0)
    |> validate_number(:golden_keys, greater_than: 0)
  end

  def to_filters(%Ecto.Changeset{valid?: false} = changeset), do: {:error, changeset}

  def to_filters(%Ecto.Changeset{} = changeset) do
    filters = apply_changes(changeset)

    filters = [
      item_base_filters(filters),
      price_filters(filters.price),
      mods_filter(filters.properties, :property),
      mods_filter(filters.implicit_mods, :implicit),
      mods_filter(filters.explicit_mods, :explicit)
    ]

    filters =
      filters
      |> List.flatten()
      |> Enum.reject(&discard_filter?/1)

    {:ok, filters}
  end

  defp item_base_filters(filters) do
    [
      {:item_base, filters.item_base_slug},
      {:rarities, filters.rarities}
    ]
  end

  defp price_filters(%__MODULE__.Price{} = price) do
    [
      {:price, :gold, price.gold_op, price.gold},
      {:price, :golden_keys, price.golden_keys_op, price.golden_keys}
      # {:price, :open_for_offers, :eq, price.open_for_offers}
    ]
  end

  defp mods_filter(mods, type) do
    Enum.map(mods, fn
      %NumMod{} = mod ->
        {type, mod.slug, mod.op, mod.value}

      %PropMod{} = mod ->
        {type, mod.slug, :eq, mod.prop}
    end)
  end

  defp discard_filter?({:rarities, rarities}) when is_list(rarities) do
    rarities
    |> MapSet.new()
    |> MapSet.equal?(@all_rarities_set)
  end

  defp discard_filter?({_, _, _, nil}), do: true
  defp discard_filter?({_, nil}), do: true
  defp discard_filter?(_), do: false
end
