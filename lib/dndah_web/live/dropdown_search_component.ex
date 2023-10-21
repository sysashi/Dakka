defmodule DndahWeb.DropdownSearchComponent do
  use DndahWeb, :live_component

  def clear(id) do
    send_update(__MODULE__, id: id, reset: true)
  end

  attr :id, :any, required: true
  attr :form, :any, default: nil
  attr :field, :any, default: nil
  attr :results, :list, default: []
  attr :on_change, :string
  attr :result_click, :any, default: nil
  attr :placeholder, :string, default: nil
  attr :search_fun, :any
  attr :search_param, :string, default: nil
  attr :class, :string, default: nil

  def render(assigns) do
    assigns = assign_new(assigns, :search_id, fn -> "#{assigns.id}_dropdown_search_results" end)

    ~H"""
    <section id={@id}>
      <div
        class="relative"
        phx-click-away={hide("##{@search_id}")}
        phx-window-keydown={hide("##{@search_id}") |> JS.push_focus(to: "##{@id}_input")}
        phx-key="escape"
      >
        <.form :if={!@field} for={@search_form}>
          <.search_input
            id={"#{@id}_input"}
            placeholder={@placeholder}
            field={@search_form[:query]}
            on_focus={show("##{@search_id}")}
            show_on_focus={@show_on_focus}
            target={@myself}
            class={@class}
          />
        </.form>

        <.search_input
          :if={@field}
          search_param={@search_param}
          id={"#{@id}_input"}
          target={@myself}
          placeholder={@placeholder}
          field={@search_form[:query]}
          on_focus={show("##{@search_id}")}
          show_on_focus={@show_on_focus}
          class={@class}
        />

        <ul
          :if={@any_results?}
          class="text-white rounded-b-md bg-zinc-700 absolute z-10 w-full border-x border-b border-gray-500 overflow-auto max-h-[382px] placeholder-white empty:border-white"
          id={@search_id}
          phx-update="stream"
        >
          <li
            :for={{id, {result, _}} <- @streams.results}
            id={id}
            class="flex items-center hover:cursor-pointer hover:bg-zinc-600 last:rounded-b-md p-2 border-b border-slate-600"
            phx-click={
              @result_click &&
                @result_click.(result)
                |> hide("##{@search_id}")
                |> JS.push("clear", target: @myself)
            }
          >
            <%= render_slot(@result, %{result: result, search_id: @search_id}) %>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  attr :field, :any, required: true
  attr :placeholder, :string
  attr :on_focus, :any
  attr :target, :any
  attr :id, :any
  attr :search_param, :string, default: nil
  attr :show_on_focus, :boolean, default: false
  attr :class, :string, default: nil

  defp search_input(assigns) do
    ~H"""
    <.input
      id={@id}
      phx-change="search"
      phx-target={@target}
      phx-debounce="200"
      type="text"
      field={@field}
      name={@search_param || @field.name}
      phx-click={@on_focus}
      class!={[
        "w-full bg-zinc-700 text-white border border-gray-500",
        "placeholder-gray-400 placeholder:italic",
        @class
      ]}
      placeholder={@placeholder}
      autocomplete="off"
    />
    """
  end

  def mount(socket) do
    uniqe_id = socket.assigns.myself.cid

    socket =
      socket
      |> assign(:show_on_focus, false)
      |> assign(:any_results?, false)
      |> assign(:search_param, nil)
      |> assign(:search_form, search_form())
      |> stream_configure(:results,
        dom_id: fn {item, index} -> "results-#{uniqe_id}-#{item.id}-#{index}" end
      )
      |> stream(:results, [])

    {:ok, socket}
  end

  def update(%{reset: true}, socket) do
    {:ok, reset_search(socket)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("search", params, socket) do
    search_param = socket.assigns.search_param

    query =
      case params do
        %{"search" => %{"query" => query}} ->
          query

        %{^search_param => query} ->
          query
      end

    results = socket.assigns.search_fun.(query)

    socket =
      socket
      |> stream(:results, [], reset: true)
      |> assign_results(results)
      |> assign(:search_form, search_form(query))

    {:noreply, socket}
  end

  def handle_event("clear", _, socket) do
    {:noreply, reset_search(socket)}
  end

  defp reset_search(socket) do
    socket
    |> assign(:any_results?, false)
    |> assign(:search_form, search_form())
    |> stream(:results, [], reset: true)
  end

  defp search_form(query \\ "") do
    to_form(%{"query" => query}, as: :search)
  end

  defp assign_results(socket, results) do
    results
    |> Enum.with_index()
    |> Enum.reduce(socket, fn {item, index}, socket ->
      stream_insert(socket, :results, {item, index}, at: index)
    end)
    |> assign(:any_results?, Enum.any?(results))
  end
end
