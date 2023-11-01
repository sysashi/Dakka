defmodule DakkaWeb.GameComponents do
  use Phoenix.Component
  use DakkaWeb, :verified_routes

  import DakkaWeb.CoreComponents

  alias Dakka.Accounts.UserSettings

  def item_image_path(%{icon_path: icon_path}), do: ~p"/images/item_base_icons/#{icon_path}"
  def item_image_path(icon) when is_binary(icon), do: ~p"/images/item_base_icons/#{icon}"

  attr :amount, :integer, default: nil

  def gold(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <div class="max-w-[48px]">
        <img
          alt="currency coins"
          height="36"
          width="36"
          class="h-auto w-full"
          src={item_image_path("misc_currency_gold_coins.webp")}
        />
      </div>
      <span :if={@amount} class="text-white font-semibold break-all"><%= @amount %></span>
    </div>
    """
  end

  attr :amount, :integer, default: nil

  def golden_key(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <div class="max-w-[48px]">
        <img
          height="180"
          width="90"
          class="h-auto w-full"
          alt="currency golden key"
          src={item_image_path("utility_golden_key.webp")}
        />
      </div>
      <span :if={@amount} class="text-white font-semibold break-all"><%= @amount %></span>
    </div>
    """
  end

  attr :rarities, :list, default: []
  attr :on_click, :any, default: nil
  attr :active, :string, default: nil
  attr :class, :any, default: nil
  attr :rarity_class, :any, default: nil

  def item_rarities(assigns) do
    ~H"""
    <div class={["flex flex-wrap", @class]}>
      <div
        :for={%{"rarity" => rarity, "rarity_rank" => rank} = record <- @rarities}
        phx-click={@on_click && @on_click.(record)}
        title={String.capitalize(rarity)}
        style={
          # "grid-column: #{rank}"
          "order: #{rank}"
        }
        class={[
          "h-[40px] w-[40px] hover:border-b-2 hover:border-cyan-300 shadow-inner shadow-white hover:cursor-pointer",
          if(@active == rarity, do: "border-b-2 border-cyan-300"),
          @rarity_class
        ]}
      >
        <span class={[
          "capitalize flex items-center shadow-inner h-full w-full justify-center hover:shadow-gray-800",
          "border font-mono text-sm #{rarity_colors(rarity)}"
        ]}>
          <%= String.first(rarity) %>
        </span>
      </div>
    </div>
    """
  end

  attr :item, :any, required: true
  attr :lang, :atom, default: :en
  attr :class, :string, default: nil
  attr :rest, :global

  def item_title(assigns) do
    assigns = assign_new(assigns, :item_base, fn -> item_base(assigns.item) end)

    ~H"""
    <section
      class={[
        @class,
        "flex justify-center border #{rarity_colors(@item_base.item_rarity.slug)}"
      ]}
      @rest
    >
      <h4 class="text-md px-1 py-1 font-semibold"><%= string(@item_base, :name, @lang) %></h4>
    </section>
    """
  end

  attr :lang, :atom, default: :en
  attr :item, :any, required: true
  attr :display_settings, :any, default: %UserSettings.Display{}

  def item_card(assigns) do
    assigns =
      assign_new(assigns, :item_base, fn -> item_base(assigns.item) end)

    ~H"""
    <article class={
      [
        "border border-zinc-700 flex flex-col bg-zinc-800",
        # card inner shadow
        "before:shadow-[inset_0px_0px_40px_4px_rgba(0,0,0,0.8)] before:absolute relative before:block",
        "before:content-[''] before:inset-x-0 before:inset-y-0 before:pointer-events-none before:h-auto"
      ]
    }>
      <header class={"flex justify-center border-b last:border-b-0 text-center #{rarity_colors(@item_base.item_rarity.slug)}"}>
        <h3 class="text-xl px-4 py-3 font-semibold"><%= string(@item_base, :name, @lang) %></h3>
      </header>

      <div :if={@display_settings.show_item_icon} class="flex justify-center">
        <%= if @item_base.icon_path do %>
          <div class="inline-flex max-h-[140px] mt-2">
            <img
              height="140"
              width="90"
              alt={string(@item_base, :name, @lang)}
              class="h-auto w-full object-contain drop-shadow-[5px_5px_5px_rgba(22,22,24,0.80)]"
              src={item_image_path(@item_base)}
            />
          </div>
        <% else %>
          <div class="justify-center items-center flex flex-col mt-2">
            <.icon name="hero-question-mark-circle" class="w-20 h-20 text-red-300" />
            <span class="text-red-300"> Missing Icon </span>
          </div>
        <% end %>
      </div>

      <section
        :if={Enum.any?(@item.implicit_mods) || Enum.any?(@item.explicit_mods)}
        class="mt-2 last:mb-2"
      >
        <.item_mods implicit={@item.implicit_mods} explicit={@item.explicit_mods} lang={@lang} />
        <.group_separator
          :if={Enum.any?(@item_base.properties) && @display_settings.show_item_properties}
          dotted
        />
      </section>

      <.item_properties
        :if={@display_settings.show_item_properties}
        properties={@item_base.properties}
        lang={@lang}
      />

      <section
        :if={@display_settings.show_item_flavor_text}
        class="text-[#86644f] px-4 text-center mb-2"
      >
        <.group_separator />
        <%= string(@item_base, :flavor_text, @lang) %>
      </section>
    </article>
    """
  end

  defp item_base(%Dakka.Game.ItemBase{} = base), do: base
  defp item_base(%Dakka.Inventory.UserGameItem{item_base: base}), do: base

  def rarity_colors("junk"), do: "bg-zinc-800 text-zinc-500 border-zinc-600"
  def rarity_colors("poor"), do: "bg-zinc-700 text-zinc-400 border-zinc-500"
  def rarity_colors("common"), do: "bg-zinc-600 text-gray-200 border-zinc-400"
  def rarity_colors("uncommon"), do: "bg-lime-950 text-lime-500 border-lime-500"
  def rarity_colors("rare"), do: "bg-[#06141f] text-blue-500 border-blue-500"
  def rarity_colors("epic"), do: "bg-[#351743] text-purple-500 border-purple-600"
  def rarity_colors("legendary"), do: "bg-[#2d1804] text-orange-500 border-orange-500"
  def rarity_colors("unique"), do: "bg-[#453f32] text-amber-200 border-amber-200"
  def rarity_colors(_), do: "bg-red-950 text-white border-b-red-600"

  attr :lang, :atom, default: :en
  attr :implicit, :list, default: []
  attr :explicit, :list, default: []

  defp item_mods(assigns) do
    ~H"""
    <section class="text-white flex flex-col">
      <.item_mod
        :for={mod <- @implicit}
        mod={mod}
        type={:implicit}
        lang={@lang}
        color="text-zinc-200"
      />
      <.item_mod
        :for={mod <- @explicit}
        :if={Enum.any?(@explicit)}
        mod={mod}
        type={:explicit}
        color="text-blue-500"
        lang={@lang}
        signed
      />
    </section>
    """
  end

  attr :mod, :any, required: true
  attr :lang, :atom, default: :en
  attr :type, :atom, required: true, values: [:implicit, :explicit, :property]
  attr :color, :string, default: nil
  attr :signed, :boolean, default: false

  defp item_mod(assigns) do
    ~H"""
    <div class={"flex justify-between px-2 #{@color}"}>
      <span class="font-bold">-</span>
      <span class="text-center">
        <%= "#{string(@mod, :name, @lang)} #{min_max_or_value(@mod, signed: @signed)}" %>
      </span>
      <span class="font-bold">-</span>
    </div>
    """
  end

  attr :lang, :atom, default: :en
  attr :properties, :list, default: []

  defp item_properties(assigns) do
    assigns =
      assign_new(assigns, :by_mod, fn ->
        Dakka.Game.ItemBase.sort_properties(assigns.properties)
      end)

    ~H"""
    <section class="text-white flex flex-col">
      <.item_property
        :for={{slug, property} <- @by_mod}
        label={Recase.to_title(slug) <> ":"}
        inline={slug != "required_class"}
        lang={@lang}
        property={property}
      />
    </section>
    """
  end

  attr :lang, :atom, default: :en
  attr :label, :string
  attr :inline, :boolean, default: true
  attr :property, :any

  defp item_property(assigns) do
    ~H"""
    <div class={"flex items-center justify-center space-x-1 #{!@inline && "flex-col"}"}>
      <span class="text-gray-600"><%= @label %></span>
      <div class="flex flex-col items-center text-[#a1968b]">
        <%= item_property_values(@property.item_mod_values, @lang) %>
      </div>
    </div>
    """
  end

  defp item_property_values(values, lang) do
    values
    |> Enum.map(&string(&1, :name, lang))
    |> Enum.join(", ")
  end

  attr :dotted, :boolean, default: false
  attr :class, :string, default: nil

  def group_separator(assigns) do
    ~H"""
    <div class={[
      "justify-center items-center px-2 text-gray-400 flex min-h-[20px]",
      "before:h-[1px] before:flex-1 before:bg-gradient-to-r before:from-gray-900 before:to-gray-400",
      "after:h-[1px] after:flex-1 after:bg-gradient-to-l after:from-gray-900 after:to-gray-400",
      @class
    ]}>
      <.icon :if={@dotted} name="hero-ellipsis-horizontal" class="h-5 w-5" />
    </div>
    """
  end

  defp string(%{strings: strings, slug: slug}, key, lang) do
    strings[key][lang] || strings[key][:en] || slug
  end

  defp string(%{item_mod: %{strings: strings, slug: slug}}, key, lang) do
    strings[key][lang] || strings[key][:en] || slug
  end

  defp string(%{label: label}, _, _), do: label

  defp string(_, key, _lang) do
    inspect(key)
  end

  defp min_max_or_value(%{value: value, value_type: value_type}, opts)
       when not is_nil(value_type) do
    format_value(value, value_type, opts)
  end

  defp min_max_or_value(
         %{min_value: val, max_value: val, item_mod: %{value_type: value_type}},
         opts
       ),
       do: format_value(val, value_type, opts)

  defp min_max_or_value(
         %{min_value: min, max_value: max, item_mod: %{value_type: value_type}},
         _opts
       ) do
    Enum.join(
      [
        format_value(min, value_type),
        format_value(max, value_type)
      ],
      "-"
    )
  end

  defp min_max_or_value(%{value: value, item_mod: %{value_type: value_type}}, opts) do
    format_value(value, value_type, opts)
  end

  defp min_max_or_value(%{value: value}, _opts) do
    value
  end

  defp format_value(val, type, opts \\ [])

  defp format_value(val, :integer, opts) when is_integer(val) do
    if opts[:signed], do: "#{sign(val)}#{val}", else: val
  end

  defp format_value(int_val, :percentage, opts) when is_integer(int_val) do
    val =
      int_val
      |> Decimal.new()
      |> Decimal.div(10)

    if opts[:signed], do: "#{sign(int_val)}#{val}%", else: "#{val}%"
  end

  defp format_value(val, :predefined_value, _opts), do: "#{val}"

  defp sign(num) when is_number(num) and num > 0, do: "+"
  defp sign(num) when is_number(num) and num < 0, do: "-"
  defp sign(_num), do: ""

  attr :result, :map
  attr :class, :string, default: nil

  def item_mod_search_result(assigns) do
    ~H"""
    <div class="flex w-full justify-between items-center">
      <span class={@class}><%= @result.localized_string || @result.in_game_id %></span>
      <%= value_type_label(@result) %>
    </div>
    """
  end

  def value_type_label(%{value_type: :integer} = assigns) do
    ~H"""
    <span
      title="integer"
      class="font-mono font-semibold border text-xs rounded-sm bg-green-700 border-green-300 py-[1px] px-[2px] whitespace-nowrap inline-block mt-[5px]"
    >
      i
    </span>
    """
  end

  def value_type_label(%{value_type: :percentage} = assigns) do
    ~H"""
    <span
      title="percentage"
      class="font-mono font-bold border text-xs rounded-sm bg-sky-700 border-sky-300 py-[1px] px-[2px] whitespace-nowrap inline-block mt-[5px]"
    >
      %
    </span>
    """
  end

  def value_type_label(%{value_type: :predefined_value} = assigns) do
    ~H"""
    <span
      title="property"
      class="font-mono font-bold border text-xs rounded-sm bg-sky-700 border-sky-300 py-[1px] px-[2px] whitespace-nowrap inline-block mt-[5px]"
    >
      prop
    </span>
    """
  end

  def value_type_label(assigns), do: ~H"<%= @value_type %>"

  ## Rarity

  @doc """
  Generate a checkbox group for multi-select.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :field, :any, doc: "a %Phoenix.HTML.Form{}/field name tuple, for example: {f, :email}"
  attr :errors, :list
  attr :required, :boolean, default: false
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :rest, :global, include: ~w(disabled form readonly)
  attr :class, :string, default: nil

  def rarities_picker(%{field: field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: assigns.id || field.id)
      |> assign_new(:name, fn -> field.name <> "[]" end)
      |> assign_new(:foo, fn -> field.name end)
      |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name} class="text-sm">
      <.label for={@id}><%= @label %></.label>
      <div class="mt-1 w-full text-left cursor-default focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
        <div class="flex gap-2 flex-wrap mt-2">
          <div :for={{label, value} <- @options} class="flex items-center">
            <label
              for={"#{@name}-#{value}"}
              class="font-medium text-gray-700 hover:cursor-pointer"
              title={label}
            >
              <input
                type="checkbox"
                id={"#{@name}-#{value}"}
                name={@name}
                value={value}
                checked={value in @value}
                class="hidden peer"
                {@rest}
              />
              <span class={[
                "peer-checked:brightness-110 px-2 py-1 brightness-50",
                "capitalize flex items-center shadow-inner h-full w-full justify-center hover:shadow-gray-800",
                "border font-mono text-sm #{rarity_colors(value)} leading-snug"
              ]}>
                <%= label %>
              </span>
            </label>
          </div>
        </div>
      </div>
      <input type="hidden" name={@name} />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  attr :type, :atom
  attr :int_field, :any
  attr :float_field, :any

  def numerical_mod_input(assigns) do
    ~H"""
    <.input
      type="number"
      step={if @type == :percentage, do: "0.1", else: "1"}
      field={if @type == :percentage, do: @float_field, else: @int_field}
      class!={
        fn errors ->
          [
            "inline-flex bg-zinc-800 max-w-[80px] border-slate-500 border-l-transparent p-1.5 text-center",
            errors != [] &&
              "border-x-red-400 border-t-red-400 border-b-red-400 focus:border-rose-400"
          ]
        end
      }
      hide_errors
    />
    """
  end
end
