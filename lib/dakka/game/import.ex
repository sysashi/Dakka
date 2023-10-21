defmodule Dakka.Game.Import do
  @moduledoc false

  require Logger

  alias Dakka.Repo

  alias Dakka.Game.{
    Language,
    TranslationString,
    ItemMod,
    ItemModValue,
    ItemBase,
    ItemBaseMod,
    ItemBaseModValue,
    ItemRarity
  }

  alias Ecto.Multi

  def item_mod_lookup_table() do
    mods =
      ItemMod
      |> Repo.all()
      |> Enum.map(&{{:item_mod, &1.slug}, &1.id})
      |> Enum.into(%{})

    mod_values =
      ItemModValue
      |> Repo.all()
      |> Enum.map(&{{:item_mod_value, &1.slug}, &1.id})
      |> Enum.into(%{})

    Map.merge(mods, mod_values)
  end

  def insert_item_base(params, lang_lookup_fun, rarity_lookup_fun, mod_lookup_fun) do
    rarity = rarity_lookup_fun.(params.rarity)
    strings = get_strings(params)
    changeset = ItemBase.build(rarity, params)

    multi =
      Multi.new()
      |> Multi.insert(:item_base, changeset)
      |> Multi.insert_all(
        :strings,
        TranslationString,
        &build_strings(&1.item_base, strings, lang_lookup_fun),
        conflict_target: [:key, :language_id, :item_base_id, :item_mod_id, :item_mod_value_id],
        on_conflict: :nothing
      )
      |> Multi.merge(&insert_item_base_mods(&1.item_base, params.item_mods, mod_lookup_fun))

    case Repo.transaction(multi) do
      {:ok, %{item_base: item_base}} ->
        {:ok, item_base}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp insert_item_base_mods(_item_base, [], _), do: Multi.new()

  defp insert_item_base_mods(item_base, mods, mod_lookup_fun) do
    {multi, _} =
      mods
      |> Enum.group_by(&{&1.mod_type, &1.item_mod_slug})
      |> Enum.reduce({Multi.new(), 0}, fn
        {{single_value_type, mod_slug}, [mod | rest]}, {multi, index}
        when single_value_type in [:implicit, :explicit] ->
          unless Enum.empty?(rest) do
            Logger.warning(
              "Got multiple entries for single #{single_value_type} value mod: #{inspect(rest)}"
            )
          end

          params = %{
            mod_type: single_value_type,
            min_value: mod[:min_value],
            max_value: mod[:max_value],
            item_mod_id: mod_lookup_fun.({:item_mod, mod_slug})
          }

          changeset = ItemBaseMod.build(item_base, params)

          {Multi.insert(multi, {:item_base_mod, index}, changeset), index + 1}

        {{:property, mod_slug}, values}, {multi, index} ->
          multi_key = {:item_base_mod, index}

          params = %{
            mod_type: :property,
            item_mod_id: mod_lookup_fun.({:item_mod, mod_slug})
          }

          changeset = ItemBaseMod.build(item_base, params)

          multi =
            multi
            |> Multi.insert(multi_key, changeset)
            |> Multi.insert_all(
              {multi_key, :values},
              ItemBaseModValue,
              fn %{^multi_key => parent} ->
                prepare_base_mod_values(parent, values, mod_lookup_fun)
              end
            )

          {multi, index + 1}
      end)

    multi
  end

  defp prepare_base_mod_values(parent, values, mod_lookup_fun) do
    Enum.map(values, fn %{value: value} ->
      %{
        item_base_mod_id: parent.id,
        item_mod_value_id: mod_lookup_fun.({:item_mod_value, value})
      }
    end)
  end

  def insert_item_mod(params, lang_lookup_fun \\ nil) do
    lookup_fun = lang_lookup_fun || default_lang_lookup_fun()
    multi = insert_item_mod_multi(params, lookup_fun)

    case Repo.transaction(multi) do
      {:ok, %{item_mod: item_mod}} ->
        {:ok, item_mod}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp insert_item_mod_multi(params, lang_lookup_fun) do
    strings = get_strings(params)
    predefined_values = get_mod_values(params)

    changeset = ItemMod.build(params)

    Multi.new()
    |> Multi.insert(:item_mod, changeset)
    |> Multi.insert_all(
      :strings,
      TranslationString,
      &build_strings(&1.item_mod, strings, lang_lookup_fun)
    )
    |> Multi.merge(&insert_item_mod_values_multi(&1.item_mod, predefined_values, lang_lookup_fun))
  end

  defp insert_item_mod_values_multi(_, [], _), do: Multi.new()

  defp insert_item_mod_values_multi(item_mod, values, lang_lookup_fun) do
    Enum.reduce(values, Multi.new(), fn %{slug: slug} = params, multi ->
      strings = get_strings(params)
      changeset = ItemModValue.build(item_mod, params)

      multi
      |> Multi.insert({:item_mod_value, slug}, changeset)
      |> Multi.insert_all(
        {:strings, slug},
        TranslationString,
        &build_strings(Map.fetch!(&1, {:item_mod_value, slug}), strings, lang_lookup_fun)
      )
    end)
  end

  def insert_languages(params) when is_list(params) do
    Repo.insert_all(
      Language,
      params,
      conflict_target: [:code],
      on_conflict: {:replace, [:name]},
      returning: true
    )
  end

  def insert_item_rarities(params) when is_list(params) do
    Repo.insert_all(
      ItemRarity,
      params,
      conflict_target: [:slug],
      on_conflict: :nothing,
      returning: true
    )
  end

  defp build_strings(entity, strings, lang_lookup_fun) do
    for string <- strings do
      %{
        language_id: lang_lookup_fun.(string["lang"]),
        key: String.to_atom(string["key"] || "name"),
        value: string["value"]
      }
      |> put_parent_id(entity)
    end
  end

  defp put_parent_id(string, %ItemBase{id: id}), do: Map.put(string, :item_base_id, id)
  defp put_parent_id(string, %ItemMod{id: id}), do: Map.put(string, :item_mod_id, id)
  defp put_parent_id(string, %ItemModValue{id: id}), do: Map.put(string, :item_mod_value_id, id)

  def default_lang_lookup_fun(langs \\ []) when is_list(langs) do
    languages =
      if Enum.empty?(langs), do: Repo.all(Language), else: langs

    lookup_table =
      for lang <- languages, into: %{} do
        {lang.code, lang.id}
      end

    fn code -> Map.fetch!(lookup_table, Language.to_code(code)) end
  end

  defp get_strings(%{strings: strings}) when is_list(strings), do: strings
  defp get_strings(%{"strings" => strings}) when is_list(strings), do: strings
  defp get_strings(_), do: []

  defp get_mod_values(%{predefined_values: vals}) when is_list(vals), do: vals
  defp get_mod_values(%{"predefined_values" => vals}) when is_list(vals), do: vals
  defp get_mod_values(_), do: []
end
