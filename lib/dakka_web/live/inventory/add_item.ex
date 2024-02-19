defmodule DakkaWeb.Inventory.AddItemLive do
  use DakkaWeb, :live_component

  import DakkaWeb.GameComponents

  alias Dakka.{Game, Inventory}
  alias Phoenix.LiveView.AsyncResult

  # upgrade rarity by mods count?
  # item base loading thing
  # picture upload and OCR

  defp item_placeholder(assigns) do
    ~H"""
    <div class="w-full h-96 justify-center items-center flex">
      <svg class="text-white animate-spin h-10 w-10 mr-3 ..." viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
        </circle>
        <path
          class="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        >
        </path>
      </svg>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <article class="max-w-2xl mx-auto">
      <.live_component
        id="item_base_search"
        module={DakkaWeb.DropdownSearchComponent}
        search_fun={&Dakka.Game.search_item_base/1}
        placeholder="Enter item base name..."
        result_click={
          fn result ->
            JS.push("set_item_base", value: result, page_loading: true, target: @myself)
          end
        }
      >
        <:result :let={%{result: result, search_id: dropdown_id}}>
          <div class="pr-1 pt-1">
            <%= if result.icon_path do %>
              <div class="border border-slate-600 bg-slate-900 rounded-md">
                <img class="object-contain h-[50px] w-[50px]" src={item_image_path(result)} />
              </div>
            <% else %>
              <div class="justify-center items-center flex flex-col border border-slate-600 bg-slate-900 rounded-md h-[54px] w-[54px]">
                <.icon name="hero-question-mark-circle" class="w-12 h-12 text-red-300 p-1" />
              </div>
            <% end %>
          </div>
          <div class="flex-1 ml-1"><%= result.localized_string %></div>
          <.item_rarities
            class="gap-2 ml-2"
            rarity_class="w-[30px] h-[30px] sm:w-[40px] sm:h-[40px]"
            rarities={result.rarities}
            on_click={
              fn rarity ->
                JS.push("set_item_base",
                  value: %{
                    id: rarity["id"],
                    rarities: result.rarities,
                    clear_dropdown: true
                  },
                  page_loading: true,
                  target: @myself
                )
                |> hide("##{dropdown_id}")
              end
            }
            active={result.rarity}
          />
        </:result>
      </.live_component>

      <.async_result :let={item_preview} assign={@item_preview}>
        <:loading :let={state}>
          <div class="text-white">
            <%= if state == :not_set do %>
              <div class="mt-4 text-center hidden">
                <.icon name="hero-arrow-up" class="text-gray-500 w-6 h-6" />
                <h3 class="mt-2 text-2xl text-gray-500">Select Item Base</h3>
              </div>
            <% else %>
              <div class="mt-2">
                <.item_placeholder />
              </div>
            <% end %>
          </div>
        </:loading>
        <:failed :let={_reason}>
          <span class="text-white">There was an error loading the item</span>
        </:failed>
        <div class="sm:flex mt-2" id="custom_item_container">
          <div
            class="self-start flex-1"
            phx-mounted={
              JS.transition(
                {"ease-out duration-500", "opacity-0", "opacity-100"},
                to: "#custom_item_container"
              )
            }
          >
            <.item_card item={item_preview} display_settings={@display_settings} />
            <div class="mt-2">
              <.item_rarities
                class="justify-between mb-2"
                rarities={@rarities}
                on_click={
                  fn rarity ->
                    JS.push("set_item_base_rarity", value: %{id: rarity["id"]}, target: @myself)
                  end
                }
                active={item_preview.item_base.item_rarity.slug}
              />
            </div>
          </div>
          <div class="border border-gray-700 md:ml-2 self-start flex-1">
            <.form
              for={@form}
              phx-change="validate_user_game_item"
              phx-submit="create_user_game_item"
              class="text-slate-200"
              phx-target={@myself}
            >
              <div class="space-y-2">
                <.mods
                  group_name="Implicit Mods"
                  field={@form[:implicit_mods]}
                  drop_param="impl_drop"
                  sort_param="impl_sort"
                  search_field={@form[:impl_search]}
                  mod_search_type={:implicit}
                  myself={@myself}
                />

                <.mods
                  group_name="Explicit Mods"
                  field={@form[:explicit_mods]}
                  drop_param="expl_drop"
                  sort_param="expl_sort"
                  search_field={@form[:expl_search]}
                  mod_search_type={:explicit}
                  myself={@myself}
                />
              </div>

              <div class="flex px-2 my-2 justify-between">
                <.button type="submit" size={:md}>Add Item</.button>
                <button
                  type="button"
                  class="text-zinc-500 italic mr-2"
                  phx-click="reset"
                  phx-target={@myself}
                >
                  Cancel
                </button>
              </div>
            </.form>
          </div>
        </div>
      </.async_result>
    </article>
    """
  end

  defp mods(assigns) do
    assigns =
      assigns
      |> assign_new(:drop_name, fn -> "#{assigns.field.form.name}[#{assigns.drop_param}][]" end)
      |> assign_new(:sort_name, fn -> "#{assigns.field.form.name}[#{assigns.sort_param}][]" end)
      |> assign(:errors, Enum.map(assigns.field.errors, &translate_error(&1)))

    ~H"""
    <div phx-feedback-for={@field.name}>
      <h4 class="font-semibold text-center bg-zinc-800 p-2"><%= @group_name %></h4>
      <section class="px-2 space-y-2">
        <.inputs_for :let={mod} field={@field}>
          <input type="hidden" name={@sort_name} value={mod.index} />
          <.input type="hidden" field={mod[:label]} />
          <.input type="hidden" field={mod[:mod_type]} />
          <.input type="hidden" field={mod[:value_type]} />
          <.input type="hidden" field={mod[:item_mod_id]} />
          <div class="flex items-center justify-center">
            <span class="mr-auto inline-flex items-center">
              <.value_type_label value_type={mod[:value_type].value} />
              <span class="ml-2"><%= mod[:label].value %></span>
            </span>
            <.input
              type="number"
              step={if mod[:value_type].value == :percentage, do: "0.1", else: "1"}
              field={
                if mod[:value_type].value == :percentage, do: mod[:value_float], else: mod[:value]
              }
              class!={
                fn errors ->
                  [
                    "inline-flex bg-zinc-800 max-w-[80px] border-x-transparent border-t-transparent border-b border-slate-500",
                    errors != [] &&
                      "border-x-red-400 border-t-red-400 border-b-red-400 focus:border-rose-400"
                  ]
                end
              }
              hide_errors
            />
            <label>
              <input type="checkbox" name={@drop_name} value={mod.index} class="hidden" />
              <.icon name="hero-x-mark" class="text-red-600 w-6 h-6 ml-2" />
            </label>
          </div>
        </.inputs_for>
        <input type="hidden" name={@drop_name} />
        <div class="">
          <.live_component
            id={"#{@mod_search_type}"}
            module={DakkaWeb.DropdownSearchComponent}
            search_fun={&Dakka.Game.search_item_mod/1}
            placeholder="Enter mod name..."
            search_param={"#{@mod_search_type}_search"}
            field={@search_field}
            result_click={
              fn result ->
                JS.push("add_mod",
                  value:
                    Map.put(result, :mod_type, @mod_search_type)
                    |> Map.put(:label, result.localized_string)
                    |> Map.put(:item_mod_id, result.id),
                  target: @myself
                )
              end
            }
          >
            <:result :let={%{result: result}}>
              <.item_mod_search_result result={result} />
            </:result>
          </.live_component>
        </div>
        <.error :for={msg <- @errors}><%= msg %></.error>
      </section>
    </div>
    """
  end

  def mount(socket) do
    {:ok, reset(socket)}
  end

  def update(%{item_base: item_base, imported_data: data}, socket) do
    user_item = Inventory.build_user_item(socket.assigns.scope, item_base)
    changeset = Inventory.build_user_item_with_mods(user_item, item_base, data.mods)
    preview = Inventory.user_item_preview(changeset)

    socket =
      socket
      |> reset()
      |> assign(:form, to_form(changeset))
      |> assign(:user_item, user_item)
      |> assign(:changeset, changeset)
      |> assign(:item_preview, AsyncResult.ok(socket.assigns.item_preview, preview))

    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def reset(socket) do
    socket
    |> assign(:rarities, [])
    |> assign(:user_item, nil)
    |> assign(:item_preview, item_base_not_set())
    |> assign(:form, nil)
  end

  def handle_event("reset", _, socket) do
    {:noreply, reset(socket)}
  end

  def handle_event("set_item_base_rarity", %{"id" => id}, socket) do
    rarities = socket.assigns.rarities
    new_rarity = Enum.find(rarities, &(&1["id"] == id))

    if new_rarity do
      socket =
        socket
        |> assign(:item_preview, AsyncResult.loading())
        |> start_async(:fetch_item_base, fn -> Game.get_item_base(id) end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_item_base", %{"id" => id} = params, socket) do
    if params["clear_dropdown"] do
      DakkaWeb.DropdownSearchComponent.clear("item_base_search")
    end

    socket =
      socket
      |> assign(:rarities, params["rarities"])
      |> assign(:item_preview, AsyncResult.loading())
      |> start_async(:fetch_item_base, fn -> Game.get_item_base(id) end)

    {:noreply, socket}
  end

  def handle_event("add_mod", params, socket) do
    if changeset = socket.assigns.changeset do
      changeset =
        changeset
        |> Inventory.add_mod(params, socket.assigns.user_item.item_base)
        |> Map.put(:action, :validate)

      preview = Ecto.Changeset.apply_changes(changeset)

      socket =
        socket
        |> assign(:form, to_form(changeset))
        |> assign(:changeset, changeset)
        |> assign(:item_preview, AsyncResult.ok(socket.assigns.item_preview, preview))

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Choose Item Base first!")}
    end
  end

  def handle_event("validate_user_game_item", %{"user_game_item" => params}, socket) do
    user_item = socket.assigns.user_item

    changeset =
      user_item
      |> Inventory.change_user_item(params)
      |> Map.put(:action, :validate)

    preview = Ecto.Changeset.apply_changes(changeset)

    socket =
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:changeset, changeset)
      |> assign(:item_preview, AsyncResult.ok(socket.assigns.item_preview, preview))

    {:noreply, socket}
  end

  def handle_event("create_user_game_item", %{"user_game_item" => params}, socket) do
    user_item = socket.assigns.user_item

    case Inventory.create_user_item(
           socket.assigns.scope,
           user_item,
           params
         ) do
      {:ok, _} ->
        {:noreply, reset(socket)}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:form, to_form(changeset))

        {:noreply, socket}
    end
  end

  def handle_async(:fetch_item_base, {:ok, item_base}, socket) do
    user_item = Inventory.build_user_item(socket.assigns.scope, item_base)

    changeset =
      Inventory.user_item_base_changeset(
        user_item,
        item_base,
        fn strings -> strings[:name][:en] end
      )

    preview = Inventory.user_item_preview(changeset)

    socket =
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:user_item, user_item)
      |> assign(:changeset, changeset)
      |> assign(:item_preview, AsyncResult.ok(socket.assigns.item_preview, preview))

    {:noreply, socket}
  end

  def handle_async(:fetch_item_base, {:exit, _reason}, socket) do
    socket =
      assign(
        socket,
        :item_preview,
        AsyncResult.failed(socket.assigns.item_preview, "Failed to load Item Base")
      )

    {:noreply, socket}
  end

  def item_base_not_set(), do: AsyncResult.loading() |> AsyncResult.loading(:not_set)
end
