defmodule Dakka.ItemFilters.PropMod do
  use Ecto.Schema

  embedded_schema do
    field :slug, :string
    field :label, :string
    field :prop, :string
  end
end
