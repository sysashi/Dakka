defmodule Dakka.Repo.Migrations.CreateGameItems do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", ""

    ## Patches
    create table(:game_patches) do
      add :version, :varchar, null: false
      add :items_wipe, :boolean, default: false, null: false
      add :characters_wipe, :boolean, default: false, null: false
      add :release_date, :utc_datetime, null: false
      add :scheduled_release_at, :utc_datetime
      add :patch_notes_url, :varchar
    end

    create index(:game_patches, [:release_date])
    create index(:game_patches, [:scheduled_release_at])
    create unique_index(:game_patches, [:version])

    ## Languages
    create table(:game_languages) do
      add :name, :varchar, null: false
      add :code, :varchar, null: false
      add :eng_label, :varchar
    end

    create unique_index(:game_languages, [:code])

    ## Item Rarities
    create table(:game_item_rarities) do
      add :rarity_rank, :integer, null: false
      add :slug, :varchar, null: false
      add :in_game_id, :varchar
    end

    create unique_index(:game_item_rarities, [:slug])
    create unique_index(:game_item_rarities, [:rarity_rank])

    # Item mods
    create table(:game_item_mods) do
      add :special, :boolean, default: false, null: false
      add :slug, :varchar, null: false
      add :in_game_id, :varchar
      add :value_type, :varchar, null: false
      add :max_value, :integer
      add :min_value, :integer
    end

    create index(:game_item_mods, [:value_type])
    create unique_index(:game_item_mods, [:slug])
    create constraint(:game_item_mods, :min_lt_or_eq_max, check: ~s|min_value <= max_value|)

    # Enum for item mod values
    create table(:game_item_mods_values) do
      add :item_mod_id, references(:game_item_mods, on_delete: :delete_all), null: false
      add :slug, :varchar, null: false
      add :in_game_id, :varchar
    end

    create index(:game_item_mods_values, [:item_mod_id])
    create unique_index(:game_item_mods_values, [:slug, :item_mod_id])

    # Base Items
    create table(:game_item_bases) do
      add :container, :boolean, default: false, null: false
      add :min_capacity, :integer, default: 0
      add :max_capacity, :integer

      add :stackable, :boolean, default: false, null: true
      add :max_stack_size, :integer

      add :slug, :varchar, null: false
      add :item_rarity_id, references(:game_item_rarities, on_delete: :restrict), null: false
      add :min_explicit_mods, :integer
      add :max_explicit_mods, :integer
      add :icon_path, :varchar
      add :original_icon_file, :varchar
      add :labels, {:array, :string}, default: [], null: false
      add :in_game_id, :varchar
    end

    create index(:game_item_bases, [:slug])
    create index(:game_item_bases, [:item_rarity_id])
    create index(:game_item_bases, [:labels], using: "GIN")

    create index(:game_item_bases, ["slug gin_trgm_ops"],
             name: :game_item_bases_slug_trgm_idx,
             using: "GIN"
           )

    create unique_index(:game_item_bases, [:slug, :item_rarity_id])

    create constraint(:game_item_bases, :min_mods_lt_or_eq_max_mods,
             check: ~s|min_explicit_mods <= max_explicit_mods|
           )

    create table(:game_item_bases_mods) do
      add :mod_type, :varchar, null: false
      add :order, :integer
      add :value, :integer
      add :max_value, :integer
      add :min_value, :integer

      add :item_mod_id, references(:game_item_mods, on_delete: :delete_all), null: false
      add :item_base_id, references(:game_item_bases, on_delete: :delete_all), null: false
    end

    create index(:game_item_bases_mods, [:mod_type])
    create index(:game_item_bases_mods, [:item_mod_id])
    create index(:game_item_bases_mods, [:item_base_id, :order])

    create constraint(:game_item_bases_mods, :min_value_lt_or_eq_max_value,
             check: ~s|min_value <= max_value|
           )

    create table(:game_item_bases_mod_values) do
      add :item_base_mod_id, references(:game_item_bases_mods, on_delete: :delete_all),
        null: false

      add :item_mod_value_id, references(:game_item_mods_values, on_delete: :restrict),
        null: false
    end

    create unique_index(:game_item_bases_mod_values, [:item_base_mod_id, :item_mod_value_id])

    # Translation strings
    create table(:game_translation_strings) do
      add :key, :varchar, null: false
      add :value, :varchar, null: false

      add :language_id, references(:game_languages, on_delete: :delete_all), null: false

      add :item_base_id, references(:game_item_bases, on_delete: :delete_all)
      add :item_mod_id, references(:game_item_mods, on_delete: :delete_all)
      add :item_mod_value_id, references(:game_item_mods_values, on_delete: :delete_all)
    end

    for column <- ~w(key value item_base_id item_mod_id item_mod_value_id)a do
      create index(:game_translation_strings, [column])
    end

    create unique_index(
             :game_translation_strings,
             [
               :key,
               :language_id,
               :item_base_id,
               :item_mod_id,
               :item_mod_value_id
             ],
             name: :game_translation_strings_entity_index,
             nulls_distinct: false
           )

    create constraint(:game_translation_strings, :parent_id_must_be_set,
             check: ~s|num_nonnulls(item_base_id, item_mod_id, item_mod_value_id) = 1|
           )

    create index(:game_translation_strings, ["value gin_trgm_ops"],
             name: :game_translation_strings_value_trgm_idx,
             using: "GIN"
           )
  end
end
