defmodule DakkaWeb.Utils do
  def append_flash(socket, kind, message, opts \\ []) do
    key = "flash-#{System.unique_integer([:positive, :monotonic])}"

    flash =
      opts
      |> Map.new()
      |> Map.put(:kind, kind)
      |> Map.put(:message, message)
      |> Map.put_new(:duration, 3000)

    Phoenix.LiveView.put_flash(socket, key, flash)
  end
end
