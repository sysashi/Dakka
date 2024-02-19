defmodule Dakka.ModsParser do
  import NimbleParsec

  sign =
    empty()
    |> ascii_string([?-, ?+], 1)
    |> unwrap_and_tag(:sign)

  int_value =
    empty()
    |> ascii_string([?0..?9], min: 1)
    |> map({String, :to_integer, []})
    |> unwrap_and_tag(:int)

  float_value =
    empty()
    |> ascii_string([?0..?9], min: 1)
    |> optional(string("."))
    |> optional(ascii_string([?0..?9], min: 1))
    |> ignore(string("%"))
    |> reduce({Enum, :join, [""]})
    |> map({__MODULE__, :to_float, []})
    |> unwrap_and_tag(:percentage)

  string_value =
    string(":")
    |> string(" ")
    |> ignore()
    |> ascii_string([?a..?z, ?A..?Z], min: 1)
    |> unwrap_and_tag(:string)

  value =
    choice([float_value, int_value, string_value])

  word =
    string(" ")
    |> repeat()
    |> ignore()
    |> ascii_string([?a..?z, ?A..?Z], min: 1)
    |> ignore(optional(string(" ")))
    |> repeat()
    |> reduce({Enum, :join, [" "]})
    |> unwrap_and_tag(:mod)

  mod_value =
    optional(sign)
    |> concat(value)
    |> optional(sign)
    |> reduce({__MODULE__, :to_value, []})
    |> unwrap_and_tag(:value)

  defparsec(:mod, optional(mod_value) |> concat(word) |> optional(mod_value))

  def to_float(value) do
    {value, _} = Float.parse(value)
    value
  end

  def to_value(value) do
    value[:string] ||
      sign_value(
        value[:int] || value[:percentage],
        value[:sign]
      )
  end

  defp sign_value(value, "+") when is_number(value), do: value
  defp sign_value(value, "-") when is_number(value), do: -value
  defp sign_value(value, _) when is_number(value), do: value

  def sanitize_input(input) do
    input
    |> String.split("\n")
    |> Enum.map(&String.replace(&1, ~r/([^A-Za-z0-9\ \+%-\.:])|(^(-|o)\W)|(\W+(-|o)$)/, ""))
    |> Enum.map(&String.trim(&1, " "))
    |> Enum.filter(&(&1 != ""))
  end
end
