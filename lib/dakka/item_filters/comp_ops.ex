defmodule Dakka.ItemFilters.CompOps do
  @ops [
    {:lt, "<"},
    {:lt_or_eq, "<="},
    {:gt, ">"},
    {:gt_or_eq, ">="},
    {:eq, "="}
  ]

  # @ops_enum_type Ecto.ParameterizedType.init(Ecto.Enum, values: @ops)

  def options(), do: Enum.map(@ops, &{elem(&1, 1), elem(&1, 0)})
  def values(), do: Enum.map(options(), &elem(&1, 1))
end
