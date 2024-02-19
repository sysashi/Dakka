defmodule DakkaWeb.MarketLive.ListingFiltersFormComponent do
  use DakkaWeb, :live_component

  import DakkaWeb.GameComponents

  alias Dakka.ItemFilters
  alias Dakka.ItemFilters.CompOps

  @impl true
  def render(assigns) do
    ~H"""
    <div class="">
      <.form for={@form} phx-change="validate-item-filters" phx-target={@myself} phx-submit="search">
        <article class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 p-4">
          <section class="col-span-full space-y-4 md:space-y-0 md:flex gap-4 border-b border-zinc-600 pb-4 items-baseline">
            <div class="flex-1">
              <.label>Item Base</.label>
              <.item_base_filters form={@form} target={@myself} />
            </div>
            <div class="flex-1">
              <.rarities_picker
                options={Dakka.Game.rarity_options()}
                field={@form[:rarities]}
                label="Rarity"
              />
            </div>
            <div class="flex-1">
              <.label>Price</.label>
              <.price_filters form={@form} />
            </div>
          </section>

          <section>
            <.label>Built-in Mods</.label>
            <.mod_filters
              target={@myself}
              field={@form[:implicit_mods]}
              drop_param="impl_drop"
              sort_param="impl_sort"
              mod_type={:implicit}
            />
          </section>

          <section class="">
            <.label>Added Mods</.label>
            <.mod_filters
              target={@myself}
              field={@form[:explicit_mods]}
              drop_param="expl_drop"
              sort_param="expl_sort"
              mod_type={:explicit}
            />
          </section>

          <section>
            <.label>Properties</.label>
            <.property_filters
              target={@myself}
              field={@form[:properties]}
              drop_param="prop_drop"
              sort_param="prop_sort"
              prop_opts={@prop_opts}
            />
          </section>
        </article>
        <div class="flex justify-end px-4 pb-4 gap-4">
          <button
            class="italic text-red-500 text-sm hover:text-red-400 flex items-center group"
            type="reset"
            name="reset"
          >
            <.icon name="hero-x-mark" class="w-4 h-4 text-red-500 group-hover:text-red-400 mt-[1px]" />
            Reset
          </button>
          <.button type="submit" style={:primary}>Search</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    changeset = ItemFilters.build()

    socket =
      socket
      |> assign(:prop_opts, %{})
      |> assign(:changeset, changeset)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate-item-filters", %{"_target" => ["reset"]}, socket) do
    socket.assigns.on_search.(ItemFilters.base_filters())

    changeset = ItemFilters.change(%ItemFilters{}, %{})

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_form(changeset)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("validate-item-filters", %{"item_filters" => filters}, socket) do
    changeset =
      ItemFilters.change(%ItemFilters{}, filters)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_form(changeset)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("search", %{"item_filters" => filters}, socket) do
    changeset =
      ItemFilters.change(%ItemFilters{}, filters)
      |> Map.put(:action, :validate)

    with {:ok, filters} <- ItemFilters.to_filters(changeset) do
      socket.assigns.on_search.(filters)
    end

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_form(changeset)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("set_item_base", params, socket) do
    changeset = socket.assigns.changeset
    changeset = ItemFilters.add_item_base(changeset, params)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_form(changeset)

    {:noreply, socket}
  end

  def handle_event("add-prop-mod", params, socket) do
    %{
      "slug" => slug,
      "options" => options,
      "localized_string" => string,
      "in_game_id" => in_game_id
    } = params

    prop_opts = Enum.map(options, &List.to_tuple/1)

    params = %{
      slug: slug,
      label: string || in_game_id
    }

    changeset = socket.assigns.changeset
    changeset = ItemFilters.add_mod(changeset, params, :property)

    socket =
      socket
      |> update(:prop_opts, &Map.put_new(&1, slug, prop_opts))
      |> assign(:changeset, changeset)
      |> assign_form(changeset)

    {:noreply, socket}
  end

  def handle_event("add-mod-filter", params, socket) do
    type = String.to_existing_atom(params["mod_type"])
    changeset = socket.assigns.changeset
    changeset = ItemFilters.add_mod(changeset, params, type)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_form(changeset)

    {:noreply, socket}
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  ## Comps

  attr :form, :any
  attr :target, :any

  defp item_base_filters(assigns) do
    ~H"""
    <.input type="hidden" field={@form[:item_base_slug]} />
    <.input type="hidden" field={@form[:item_base]} />
    <div :if={@form[:item_base].value} class="text-white my-2 text-xl flex flex-col">
      <span class="font-bold"><%= @form[:item_base].value %></span>

      <div>
        <span
          class="inline-flex items-center gap-[2px] hover:cursor-pointer"
          phx-click={JS.dispatch("clear-input", to: "##{@form[:item_base_slug].id}")}
        >
          <.icon name="hero-x-mark" class="w-4 h-4 text-red-500 mt-[2px] peer-hover:text-red-400" />
          <span class="italic text-red-500 text-sm peer-hover:text-red-400">
            Remove
          </span>
        </span>
      </div>
    </div>
    <div class="mt-2"></div>
    <.live_component
      id="item_base_search"
      class="text-md"
      field="item_base"
      module={DakkaWeb.DropdownSearchComponent}
      search_fun={&Dakka.Game.search_item_base/1}
      placeholder="Enter item base name..."
      result_click={
        fn result ->
          JS.push("set_item_base",
            value: %{item_base_slug: result.slug, item_base: result.localized_string},
            page_loading: true,
            target: @target
          )
        end
      }
    >
      <:result :let={%{result: result}}>
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
        <div class="flex-1 ml-1 text-sm"><%= result.localized_string %></div>
      </:result>
    </.live_component>
    """
  end

  defp price_filters(assigns) do
    ~H"""
    <.inputs_for :let={price} field={@form[:price]}>
      <div class="flex flex-col gap-y-2 ">
        <div class="flex items-end">
          <.price_input
            placeholder="Any Price"
            label="Gold"
            icon={:gold}
            options={CompOps.options()}
            amount_field={price[:gold]}
            op_field={price[:gold_op]}
          />
        </div>
        <div class="flex items-end">
          <.price_input
            placeholder="Any Price"
            label="Keys"
            icon={:golden_key}
            options={CompOps.options()}
            amount_field={price[:golden_keys]}
            op_field={price[:golden_keys_op]}
          />
        </div>
      </div>
    </.inputs_for>
    """
  end

  attr :field, :any
  attr :mod_type, :atom
  attr :drop_param, :string
  attr :sort_param, :string
  attr :target, :any

  defp mod_filters(assigns) do
    assigns =
      assigns
      |> assign_new(:drop_name, fn -> "#{assigns.field.form.name}[#{assigns.drop_param}][]" end)
      |> assign_new(:sort_name, fn -> "#{assigns.field.form.name}[#{assigns.sort_param}][]" end)
      |> assign(:errors, Enum.map(assigns.field.errors, &translate_error(&1)))

    ~H"""
    <.inputs_for :let={mod} field={@field}>
      <input type="hidden" name={@sort_name} value={mod.index} />
      <div class="flex gap-x-2 text-white flex-col justify-center">
        <div class="flex">
          <.input type="hidden" field={mod[:slug]} />
          <.input type="hidden" field={mod[:label]} />
          <.input type="hidden" field={mod[:value_type]} />
          <span class="mr-auto inline-flex items-center">
            <.value_type_label value_type={mod[:value_type].value} />
            <span class="ml-2 text-sm"><%= mod[:label].value %></span>
          </span>
          <.input class!="min-w-[70px]" type="select" field={mod[:op]} options={CompOps.options()} />
          <.numerical_mod_input
            type={mod[:value_type].value}
            int_field={mod[:value]}
            float_field={mod[:value_float]}
          />
        </div>
        <div>
          <label class="inline-flex items-center gap-[2px] hover:cursor-pointer">
            <input type="checkbox" name={@drop_name} value={mod.index} class="hidden peer" />
            <.icon name="hero-x-mark" class="w-4 h-4 text-red-500 mt-[2px] peer-hover:text-red-400" />
            <span class="italic text-red-500 text-sm peer-hover:text-red-400">
              Remove
            </span>
          </label>
        </div>
      </div>
    </.inputs_for>
    <input type="hidden" name={@drop_name} />
    <div class="mt-2">
      <.live_component
        id={@mod_type}
        class="text-md"
        module={DakkaWeb.DropdownSearchComponent}
        search_fun={&Dakka.Game.search_item_mod/1}
        placeholder="Enter mod name..."
        search_param={"#{@mod_type}_search"}
        field={"#{@mod_type}_query"}
        result_click={
          fn result ->
            JS.push("add-mod-filter",
              value:
                Map.put(result, :mod_type, @mod_type)
                |> Map.put(:label, result.localized_string)
                |> Map.put(:item_mod_id, result.id),
              target: @target
            )
          end
        }
      >
        <:result :let={%{result: result}}>
          <.item_mod_search_result result={result} class="text-sm" />
        </:result>
      </.live_component>
    </div>
    """
  end

  attr :field, :any
  attr :drop_param, :string
  attr :sort_param, :string
  attr :prop_opts, :list, default: []
  attr :target, :any

  defp property_filters(assigns) do
    assigns =
      assigns
      |> assign_new(:drop_name, fn -> "#{assigns.field.form.name}[#{assigns.drop_param}][]" end)
      |> assign_new(:sort_name, fn -> "#{assigns.field.form.name}[#{assigns.sort_param}][]" end)
      |> assign(:errors, Enum.map(assigns.field.errors, &translate_error(&1)))

    ~H"""
    <.inputs_for :let={mod} field={@field}>
      <input type="hidden" name={@sort_name} value={mod.index} />
      <div class="flex gap-x-2 text-white flex-col justify-center">
        <div class="flex">
          <.input type="hidden" field={mod[:slug]} />
          <.input type="hidden" field={mod[:label]} />
          <span class="mr-auto inline-flex items-center">
            <span class=""><%= mod[:label].value %></span>
          </span>
          <.input type="select" field={mod[:prop]} options={@prop_opts[mod[:slug].value]} />
        </div>
        <div>
          <label class="inline-flex items-center gap-[2px] hover:cursor-pointer">
            <input type="checkbox" name={@drop_name} value={mod.index} class="hidden peer" />
            <.icon name="hero-x-mark" class="w-4 h-4 text-red-500 mt-[2px] peer-hover:text-red-400" />
            <span class="italic text-red-500 text-sm peer-hover:text-red-400">
              Remove
            </span>
          </label>
        </div>
      </div>
    </.inputs_for>
    <input type="hidden" name={@drop_name} />

    <div class="mt-2">
      <.live_component
        id="props"
        class="text-md"
        module={DakkaWeb.DropdownSearchComponent}
        search_fun={&Dakka.Game.search_item_mod(&1, value_types: :predefined_value)}
        placeholder="Enter mod name..."
        search_param="props_search"
        field="props_query"
        show_on_focus={true}
        result_click={
          fn result ->
            JS.push("add-prop-mod",
              value: result,
              target: @target
            )
          end
        }
      >
        <:result :let={%{result: result}}>
          <.item_mod_search_result result={result} class="text-sm" />
        </:result>
      </.live_component>
    </div>
    """
  end

  attr :placeholder, :string, default: nil
  attr :prompt, :string, default: nil
  attr :options, :list
  attr :label, :string
  attr :amount_field, :any
  attr :op_field, :any
  attr :icon, :atom, default: nil

  defp price_input(%{amount_field: field, op_field: op_field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(op_field: nil, op_id: op_field.id)
      |> assign(:errors, Enum.map(field.errors ++ op_field.errors, &translate_error(&1)))
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:op_name, fn -> op_field.name end)
      |> assign_new(:value, fn -> field.value end)
      |> assign_new(:op_value, fn -> op_field.value end)

    ~H"""
    <div class="flex flex-col">
      <div class="flex">
        <div phx-feedback-for={@name} class="flex items-center gap-2 basis-2/3">
          <.gold :if={@icon == :gold} />
          <.golden_key :if={@icon == :golden_key} />
          <label for={@id} class="text-gray-300 text-xs"><%= @label %></label>
          <input
            type="number"
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value("number", @value)}
            placeholder={@placeholder}
            class={[
              "bg-zinc-800 p-1.5",
              "block w-full text-zinc-100 focus:ring-0",
              "phx-no-feedback:border-zinc-600 phx-no-feedback:focus:border-zinc-500",
              @errors == [] && "border-zinc-600 focus:border-zinc-500",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ]}
          />
        </div>
        <div phx-feedback-for={@op_name} class="my-auto basis-1/4">
          <select
            id={@op_id}
            name={@op_name}
            class={[
              "block w-full border border-zinc-600 bg-zinc-700 text-zinc-50 shadow-sm focus:border-zinc-400 focus:ring-0 appearance-none p-1.5"
            ]}
          >
            <option :if={@prompt} value=""><%= @prompt %></option>
            <%= Phoenix.HTML.Form.options_for_select(@options, @op_value) %>
          </select>
        </div>
      </div>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end
end
