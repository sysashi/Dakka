defmodule Dakka.ItemFilters.NumMod do
  use Ecto.Schema

  alias Dakka.ItemFilters.CompOps

  embedded_schema do
    field :label, :string
    field :slug, :string
    field :value, :integer, default: 0
    field :value_float, :float, virtual: true
    field :value_type, Ecto.Enum, values: [:integer, :percentage, :predefined_value]
    field :op, Ecto.Enum, values: CompOps.values(), default: :gt_or_eq
  end
end
