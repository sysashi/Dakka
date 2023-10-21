defmodule DndahWeb.Game.EntitySearchLive do
  use DndahWeb, :live_view

  import DndahWeb.GameComponents

  alias Dndah.Game

  def render(assigns) do
    ~H"""
    <.form for={@search_form} phx-change="search">
      <.input type="text" field={@search_form[:id]} label="id" />
      <.button type="submit">Search</.button>
    </.form>

    <.item_card :for={entity <- @entity} :if={@entity} item={entity} />
    """
  end

  def mount(_params, _session, socket) do
    # items = Enum.map([440, 439, 438, 437, 436, 435, 434, 433], &Game.get_item_base/1)
    items = Game.all_item_bases()
    {:ok, assign(socket, :search_form, search_form()) |> assign(:entity, items)}
  end

  def handle_event("search", %{"search" => %{"id" => id}}, socket) do
    item_base = Game.get_item_base(id) || []
    {:noreply, assign(socket, :entity, List.wrap(item_base))}
  end

  defp search_form() do
    to_form(%{slug: ""}, as: :search)
  end
end
