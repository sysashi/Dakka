defmodule Dndah.Inventory.Events do
  @moduledoc """
  Inventory events
  """

  defmodule UserItemCreated do
    defstruct user_item: nil
  end

  defmodule UserItemUpdated do
    defstruct user_item: nil
  end
end
