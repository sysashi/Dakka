defmodule Dakka.Game do
  @moduledoc """
  Game and Game Items related functions
  """

  require Logger

  import Ecto.Query

  alias Dakka.Repo

  alias Dakka.Game.{
    TranslationString,
    ItemMod,
    ItemModValue,
    ItemBase,
    ItemRarity
  }

  def search_item_base(name) do
    by_string_query =
      ItemBase
      |> join(:inner, [ib], ts in TranslationString, on: ts.item_base_id == ib.id, as: :ts)
      |> join(:inner, [..., ts], lang in assoc(ts, :language), as: :lang)
      |> join(:inner, [ib], ir in assoc(ib, :item_rarity), as: :rarity)
      |> where([ts: ts, lang: lang], lang.code == ^:en and ts.key == ^:name)
      |> where([ts: ts], fragment("? <% ?", ^name, ts.value))
      |> order_by([ts: ts, rarity: rarity], asc: rarity.rarity_rank)
      |> distinct([ts: ts], ts.value)
      |> select([base, string, lang, rarity], %{
        slug_score: fragment("word_similarity(?, ?)", ^name, base.slug),
        name_score: fragment("word_similarity(?, ?)", ^name, string.value),
        localized_string: string.value,
        id: base.id,
        slug: base.slug,
        rarity: rarity.slug,
        rarity_rank: rarity.rarity_rank,
        icon_path: base.icon_path
      })

    rarities_query =
      ItemBase
      |> where([ib], ib.slug == parent_as(:ib).slug)
      |> join(:inner, [ib], ir in assoc(ib, :item_rarity))
      |> where(
        [ib, r],
        fragment(
          "case when '{armor, weapon}' && ? then ? > 3 else true end",
          ib.labels,
          r.rarity_rank
        )
      )
      |> order_by([ib, ir], asc: ir.rarity_rank)
      |> select([ib, ir], %{id: ib.id, rarity: ir.slug, rarity_rank: ir.rarity_rank})

    rarities_array_query =
      rarities_query
      |> subquery()
      |> select([r], %{
        rarities: fragment("jsonb_agg(?)", r)
      })

    query =
      from(q in subquery(by_string_query), as: :ib)
      |> order_by([q],
        desc: fragment("greatest(?, ?)", q.name_score, q.slug_score),
        asc: q.rarity_rank
      )
      |> join(:inner_lateral, [q], r in subquery(rarities_array_query), on: true)
      |> select([q, r], merge(q, %{rarities: r.rarities}))
      |> limit(20)

    {:ok, results} =
      Repo.transaction(fn repo ->
        repo.query!("set local pg_trgm.word_similarity_threshold=0.2;")
        repo.all(query)
      end)

    results
  end

  def search_item_mod(input, opts \\ []) do
    types =
      opts
      |> Keyword.get(:value_types, [:integer, :percentage])
      |> List.wrap()

    input = String.trim(input)

    options_query =
      ItemModValue
      |> join(:inner, [v], m in assoc(v, :item_mod), on: m.id == parent_as(:mod).id)
      |> join(:left, [v], ts in TranslationString, on: ts.item_mod_value_id == v.id, as: :ts)
      |> join(:inner, [ts: ts], lang in assoc(ts, :language), on: lang.code == :en)
      |> select([v, ts: ts], %{values: fragment("array_agg(array[?, ?])", ts.value, v.slug)})

    from(m in ItemMod, as: :mod)
    |> where([m], m.value_type in ^types)
    |> join(:left, [im], ts in TranslationString, on: ts.item_mod_id == im.id, as: :ts)
    |> join(:inner, [im, ts], lang in assoc(ts, :language), on: lang.code == :en, as: :lang)
    |> where([m, lang: l], l.code == :en or m.value_type == :predefined_value)
    |> join(:left_lateral, [], o in subquery(options_query), as: :options, on: true)
    # |> where([im, ts], fragment("? %> ?", ts.value, ^input))
    |> order_by([im, ts], desc: fragment("word_similarity(?, ?)", ts.value, ^input))
    |> select(
      [im, ts: ts, options: o],
      %{
        id: im.id,
        value_type: im.value_type,
        slug: im.slug,
        localized_string: ts.value,
        in_game_id: im.in_game_id,
        options: o.values
      }
    )
    |> Repo.all()
  end

  def list_item_mods(slugs) do
    options_query =
      ItemModValue
      |> join(:inner, [v], m in assoc(v, :item_mod), on: m.id == parent_as(:mod).id)
      |> join(:left, [v], ts in TranslationString, on: ts.item_mod_value_id == v.id, as: :ts)
      |> join(:inner, [ts: ts], lang in assoc(ts, :language), on: lang.code == :en)
      |> select([v, ts: ts], %{values: fragment("array_agg(array[?, ?])", ts.value, v.slug)})

    from(m in ItemMod, as: :mod)
    |> where([im], im.slug in ^slugs)
    |> join(:left, [im], ts in TranslationString, on: ts.item_mod_id == im.id, as: :ts)
    |> join(:inner, [im, ts], lang in assoc(ts, :language), on: lang.code == :en, as: :lang)
    |> where([m, lang: l], l.code == :en or m.value_type == :predefined_value)
    |> join(:left_lateral, [], o in subquery(options_query), as: :options, on: true)
    |> select(
      [im, ts: ts, options: o],
      %{
        id: im.id,
        value_type: im.value_type,
        slug: im.slug,
        localized_string: ts.value,
        in_game_id: im.in_game_id,
        options: o.values
      }
    )
    |> Repo.all()
  end

  def find_item_base_by_name(name, rarity) do
    ItemBase
    |> join(:inner, [ib], ts in TranslationString, on: ts.item_base_id == ib.id, as: :ts)
    |> join(:inner, [..., ts], lang in assoc(ts, :language), as: :lang)
    |> join(:inner, [ib], ir in assoc(ib, :item_rarity), as: :rarity)
    |> where([ts: ts, lang: lang], lang.code == ^:en and ts.key == ^:name)
    |> where([ts: ts], fragment("? <% ?", ^name, ts.value))
    |> where([rarity: rarity], rarity.slug == ^rarity)
    |> order_by([ts: ts], desc: fragment("word_similarity(?, ?)", ^name, ts.value))
    |> limit(1)
    |> preload(^item_base_preloads())
    |> select([ib], %{ib | explicit_mods: []})
    |> Repo.find()
    |> format_item_base()
  end

  def get_item_base(id) do
    ItemBase
    |> where(id: ^id)
    |> preload(^item_base_preloads())
    |> select([ib], %{ib | explicit_mods: []})
    |> Repo.one()
    |> format_item_base()
  end

  def all_item_bases() do
    ItemBase
    |> preload(^item_base_preloads())
    |> select([ib], %{ib | explicit_mods: []})
    |> Repo.all()
    |> Enum.map(&format_item_base/1)
  end

  @item_base_strings_paths [
    :strings,
    [:implicit_mods, :item_mod, :strings],
    [:properties, :item_mod, :strings],
    [:properties, :item_mod_values, :strings]
  ]

  def format_item_base({:ok, item_base}), do: {:ok, format_item_base(item_base)}

  def format_item_base(%ItemBase{} = item_base) do
    item_base
    |> drop_unnecesary_fields()
    |> group_translation_strings(@item_base_strings_paths)
  end

  def format_item_base(item_base), do: item_base

  # TODO optimize (remove extra passes) or try to avoid doing it at all
  def group_translation_strings(item, paths) do
    Enum.reduce(paths, item, fn strings_path, item ->
      traverse(strings_path, item)
    end)
  end

  defp drop_unnecesary_fields(item_mod) do
    %{item_mod | properties: Enum.map(item_mod.properties, &%{&1 | item_base_mod_values: []})}
  end

  defp traverse(:strings, data) when is_struct(data) do
    %{data | strings: group_translation_strings(data.strings)}
  end

  defp traverse([], data) when is_list(data) do
    group_translation_strings(data)
  end

  defp traverse([path | rest], data) when is_struct(data) do
    Map.put(data, path, traverse(rest, Map.fetch!(data, path)))
  end

  defp traverse([path | rest], data) when is_list(data) do
    for entry <- data do
      Map.put(entry, path, traverse(rest, Map.get(entry, path)))
    end
  end

  # Groups translation strings by key then builds a map of (lang_code => value) for each key
  # for example we got the following strings:
  #   1. %TranslationString{key: :name, value: "Boots", language: %Language{code: :en}}
  #   2. %TranslationString{key: :name, value: "...", language: %Language{code: :ja}}
  #   3. %TranslationString{key: :name, value: "...", language: %Language{code: :zh_hans}}
  # Result would be:
  #   %{name: %{en: "Boots", ja: "...", ...}}
  defp group_translation_strings(strings) do
    for {key, strings} <- Enum.group_by(strings, & &1.key), into: %{} do
      {key, Enum.reduce(strings, %{}, &Map.put(&2, &1.language.code, &1.value))}
    end
  end

  defp item_base_preloads() do
    [
      :item_rarity,
      [strings: :language],
      [
        implicit_mods: [
          item_mod: [strings: :language]
        ]
      ],
      [
        properties: [
          item_mod: [strings: :language],
          item_mod_values: [strings: :language]
        ]
      ]
    ]
  end

  def rarity_options() do
    ItemRarity
    |> order_by(:rarity_rank)
    |> Repo.all()
    |> Enum.map(&{String.capitalize(&1.slug), &1.slug})
  end
end
