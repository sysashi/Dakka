defmodule DakkaWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At the first glance, this module may seem daunting, but its goal is
  to provide some core building blocks in your application, such as modals,
  tables, and forms. The components are mostly markup and well documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import DakkaWeb.Gettext

  attr :id, :any
  attr :form, :any, default: nil
  attr :field, :any
  attr :results, :list, default: []
  attr :on_change, :string
  attr :result_click, :any
  attr :placeholder, :string, default: nil

  slot :result

  def dropdown_search(assigns) do
    ~H"""
    <div class="relative" phx-click-away={hide("##{@id}_search_results")}>
      <.form :if={@form} for={@form} phx-change={@on_change}>
        <.input
          type="text"
          field={@form[@field]}
          phx-focus={show("##{@id}_search_results")}
          class!={"w-full bg-zinc-700 text-white text-xl border border-gray-500 placeholder-gray-400 placeholder:italic #{Enum.any?(@results) && "focus:rounded-b-none"}"}
          placeholder={@placeholder}
        />
      </.form>

      <.input
        :if={!@form}
        type="text"
        field={@field}
        phx-focus={show("##{@id}_search_results")}
        class!={"w-full bg-zinc-700 text-white text-md border border-gray-500 placeholder-gray-400 placeholder:italic #{Enum.any?(@results) && "focus:rounded-b-none"}"}
        placeholder={@placeholder}
        autocomplete="off"
      />

      <ul
        :if={Enum.any?(@results)}
        class="text-white rounded-b-md bg-zinc-700 absolute z-10 w-full border-x border-b border-gray-500 overflow-auto max-h-[382px] placeholder-white"
        id={"#{@id}_search_results"}
      >
        <li
          :for={result <- @results}
          class="flex items-center hover:cursor-pointer hover:bg-zinc-600 last:rounded-b-md p-2 border-b border-slate-600 h-[76px]"
          phx-click={@result_click && @result_click.(result) |> hide("##{@id}_search_results")}
        >
          <%= render_slot(@result, result) %>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-zinc-900/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden bg-zinc-800 p-8 shadow-lg ring-1 transition border border-zinc-700"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-70 hover:opacity-90"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="text-white h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, default: "flash", doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} title="Success!" flash={@flash} />
    <.flash kind={:error} title="Error!" flash={@flash} />
    <.flash
      id="client-error"
      kind={:error}
      title="We can't find the internet"
      phx-disconnected={show(".phx-client-error #client-error")}
      phx-connected={hide("#client-error")}
      hidden
    >
      Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>

    <.flash
      id="server-error"
      kind={:error}
      title="Something went wrong!"
      phx-disconnected={show(".phx-server-error #server-error")}
      phx-connected={hide("#server-error")}
      hidden
    >
      Hang in there while we get back on track
      <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-10 space-y-8">
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          <%= render_slot(action, f) %>
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  attr :style, :atom, values: [:primary, :secondary, :extra], default: :primary
  attr :size, :atom, values: [:sm, :md, :xl], default: :md

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        button_size(@size),
        button_style(@style),
        "border text-sm flex justify-center items-center",
        "phx-submit-loading:opacity-75",
        "font-semibold leading-6 active:text-white/80",
        "transition-colors duration-100",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp button_style(:primary), do: "bg-lime-700 border-green-800 hover:bg-lime-800 text-zinc-50"

  defp button_style(:secondary),
    do: "bg-zinc-800 border-zinc-700 hover:bg-green-900 text-zinc-100"

  defp button_style(:extra), do: "bg-blue-700 hover:bg-blue-800 border-blue-500 text-white"

  defp button_size(:sm), do: "py-1 px-2"
  defp button_size(:md), do: "py-2 px-3"
  defp button_size(:xl), do: "py-4 px-5"

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :placeholder, :string, default: nil

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class!, :any, default: nil
  attr :hide_errors, :boolean, default: false
  attr :hidden, :boolean, default: false

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox", value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-4 text-sm leading-6 text-zinc-200">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={[
            "rounded border-zinc-300 text-zinc-900 focus:ring-0",
            @class!
          ]}
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class={[
          "block w-full border border-zinc-600 bg-zinc-700 text-zinc-50 shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm appearance-none",
          @class!
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns = assign(assigns, :custom_class, custom_class(assigns.class!, assigns.errors))

    ~H"""
    <div phx-feedback-for={@name} class={@hidden && "hidden"}>
      <.label for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        placeholder={@placeholder}
        class={
          if(@custom_class,
            do: [
              @custom_class,
              "phx-no-feedback:border-zinc-600 phx-no-feedback:focus:border-zinc-500 focus:ring-0",
              @errors == [] && "border-zinc-600 focus:border-zinc-500"
            ],
            else: [
              "bg-zinc-700",
              "mt-2 block w-full text-zinc-100 focus:ring-0 sm:text-sm sm:leading-6",
              "phx-no-feedback:border-zinc-600 phx-no-feedback:focus:border-zinc-500",
              @errors == [] && "border-zinc-600 focus:border-zinc-500",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ]
          )
        }
        {@rest}
      />
      <.error :for={msg <- @errors} :if={!@hide_errors}><%= msg %></.error>
    </div>
    """
  end

  defp custom_class(nil, _errors), do: nil
  defp custom_class(class, _errors) when is_list(class) or is_binary(class), do: class
  defp custom_class(class_fun, errors) when is_function(class_fun, 1), do: class_fun.(errors)

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-200">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-200">
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-300">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div class="flex-none"><%= render_slot(@actions) %></div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pr-6 pb-4 font-normal"><%= col[:label] %></th>
            <th class="relative p-0 pb-4"><span class="sr-only"><%= gettext("Actions") %></span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                  <%= render_slot(col, @row_item.(row)) %>
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  <%= render_slot(action, @row_item.(row)) %>
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-zinc-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none text-zinc-500"><%= item.title %></dt>
          <dd class="text-zinc-700"><%= render_slot(item) %></dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        <%= render_slot(@inner_block) %>
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(DakkaWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(DakkaWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  def logo(assigns) do
    ~H"""
    <svg width="64" height="64" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
      <path
        fill="#FFD700"
        d="M136 25.01c-16.5 0-31.3 3.4-41.29 8.4c-9.9 5-13.7 10.6-13.7 14.6c0 3.9 3.8 9.61 13.7 14.5c9.99 5 24.79 8.5 41.29 8.5s31.3-3.5 41.2-8.5c10-4.89 13.8-10.6 13.8-14.5c0-4-3.8-9.6-13.8-14.6c-9.9-5-24.7-8.4-41.2-8.4zm160 32c-16.5 0-31.3 3.4-41.2 8.4c-10 5-13.8 10.6-13.8 14.6c0 3.9 3.8 9.61 13.8 14.5c9.9 5 24.7 8.49 41.2 8.49c4.6 0 9-.3 13.2-.8c4.3-5.49 10.4-10.36 17.5-13.6c8.2-3.7 17.7-6.7 24.3-8.59c0-4-3.8-9.6-13.8-14.6c-9.9-5-24.7-8.4-41.2-8.4zM81.01 75.4c-.4 14.66 15.48 20.64 25.49 23.6c17.9 5.2 41.1 5.2 59 0c12.8-3.66 25.4-10.72 25.5-23.6c-16.1 10.63-39.6 13.49-55 13.6c-19.5-1.63-39.98-3.65-54.99-13.6zM376 96.31c-16.5 0-31.3 3.4-41.2 8.49c-10 4.9-13.8 10.6-13.8 14.5c0 4 3.8 9.6 13.8 14.6c9.9 5 24.7 8.4 41.2 8.4c16.5 0 31.3-3.4 41.2-8.4c10-5 13.8-10.6 13.8-14.6c0-3.9-3.8-9.6-13.8-14.5c-9.9-5.09-24.7-8.49-41.2-8.49zM241 107.4v2.4c2.9 1 5.7 2.2 8.3 3.5c9 4.5 16.8 10.8 20.8 18.7c10.2 2.5 21.7 3.4 32.9 2.7v-13.9c-2.3.1-4.6.2-7 .2c-18.9 0-36.1-3.7-49.3-10.3c-2-1-3.9-2.1-5.7-3.3zm-159.99.1c-.34 14.6 15.52 20.6 25.49 23.6c6.8 1.9 14.4 3.2 22.2 3.6c2-5.2 5.6-9.8 10.2-13.7c-12.8.3-25.7-1.3-37.4-4.6c-7.79-2.3-14.69-5.2-20.49-8.9zM200 121c-16.5 0-31.3 3.5-41.2 8.4c-10 5-13.8 10.6-13.8 14.6s3.8 9.6 13.8 14.6c9.9 5 24.7 8.4 41.2 8.4c16.5 0 31.3-3.4 41.2-8.4c10-5 13.8-10.6 13.8-14.6s-3.8-9.6-13.8-14.6c-9.9-4.9-24.7-8.4-41.2-8.4zM81.01 139.5c-.34 14.6 15.52 20.6 25.49 23.6c6.3 1.8 13.3 3 20.5 3.5v-13.8c-8.8-.6-17.4-2.1-25.5-4.4c-7.79-2.3-14.69-5.2-20.49-8.9zM321 146.8c-.2 14.7 15.4 20.6 25.5 23.6c17.9 5.2 41.1 5.2 59 0c12.7-3.7 25.4-10.7 25.5-23.6c-1.8 1.1-3.7 2.2-5.7 3.2c-13.2 6.6-30.4 10.3-49.3 10.3s-36.1-3.7-49.3-10.3c-2-1-3.9-2.1-5.7-3.2zm-48 4.2v13.7c9.4 1.9 19.9 2.6 30 2v-13.8c-10.1.5-20.3-.1-30-1.9zm-128 20.4c-.5 6 2.2 10.9 5.5 13.8c4.2 3.6 11 7.3 20 9.9c17.9 5.1 41.1 5.1 59 0c9-2.6 15.8-6.3 20-9.9c4.9-4.1 5.5-8.1 5.5-13.8c-1.8 1.2-3.7 2.3-5.7 3.3c-13.2 6.6-30.4 10.3-49.3 10.3s-36.1-3.7-49.3-10.3c-2-1-3.9-2.1-5.7-3.3zm-63.99.1c-.34 14.6 15.52 20.6 25.49 23.6c6.3 1.8 13.3 3 20.5 3.5v-13.8c-8.8-.6-17.4-2.1-25.5-4.4c-7.79-2.3-14.69-5.2-20.49-8.9zM321 178.8c-.2 14.7 15.4 20.6 25.5 23.6c17.9 5.2 41.1 5.2 59 0c12.7-3.7 25.4-10.7 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.3-47.3 6.3-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm-48 4.2v13.7c9.4 1.9 19.9 2.6 30 2v-13.8c-10.1.5-20.3-.1-30-1.9zM81.01 203.5c-.34 14.6 15.52 20.6 25.49 23.6c6.3 1.8 13.3 3 20.5 3.5v-13.8c-8.8-.6-17.4-2.1-25.5-4.4c-7.79-2.3-14.69-5.2-20.49-8.9zm63.99 0c-.5 6 2.2 10.8 5.5 13.7c4.2 3.6 11 7.3 20 9.9c17.9 5.1 41.1 5.1 59 0c9-2.6 15.8-6.3 20-9.9c4.9-4.1 5.5-8 5.5-13.7c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.3 6.2-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm176 7.3c-.2 14.7 15.4 20.6 25.5 23.6c17.9 5.2 41.1 5.2 59 0c12.7-3.7 25.4-10.7 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.3-47.3 6.3-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm-48 4.2v13.7c9.4 1.9 19.9 2.6 30 2v-13.8c-10.1.5-20.3-.1-30-1.9zm-128 20.5v2.3c2.9 1 5.7 2.2 8.3 3.5c9 4.5 16.8 10.8 20.8 18.7c17.3 4.2 38.7 3.9 55.4-.9c9-2.6 15.8-6.3 20-9.9c4.9-4.1 5.5-8 5.5-13.7c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.3 6.2-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm176 7.3c-.2 14.7 15.4 20.6 25.5 23.6c17.9 5.2 41.1 5.2 59 0c12.7-3.7 25.4-10.7 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.3-47.3 6.3-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm-48 4.2v13.7c9.4 1.9 19.9 2.6 30 2v-13.8c-10.1.5-20.3-.1-30-1.9zm-169 2c-16.49 0-31.29 3.5-41.29 8.4c-9.9 5-13.7 10.6-13.7 14.6s3.8 9.6 13.7 14.6c10 5 24.8 8.4 41.29 8.4c16.5 0 31.3-3.4 41.2-8.4c10-5 13.8-10.6 13.8-14.6s-3.8-9.6-13.8-14.6c-9.9-4.9-24.7-8.4-41.2-8.4zm151 18.5c-5.8 3.7-12.7 6.6-20.5 8.9c-18 5.1-38.6 6-57.5 2.6v13.7c16.8 3.5 36.7 2.9 52.5-1.6c12.6-3.7 25.4-10.8 25.5-23.6zm66 7.3c-.3 14.2 14.7 20.3 24.6 23.3c5.6-4.5 10.7-7.9 16.7-10.4c-7.2-.8-14.2-2.1-20.8-4c-7.8-2.3-14.7-5.2-20.5-8.9zm110 0c-2.8 1.8-5.9 3.4-9.3 4.9c3.1.3 6.2.7 9.1 1.2c.4-2 .2-4 .2-6.1zM273 279v13.6c10.9 2.1 20 2.6 30 2.2v-13.9c-10.1.5-20.3-.1-30-1.9zm135 18c-16.5 0-31.3 3.5-41.2 8.4c-10 5-13.8 10.6-13.8 14.6s3.8 9.6 13.8 14.6c9.9 5 24.7 8.4 41.2 8.4c16.5 0 31.3-3.4 41.2-8.4c10-5 13.8-10.6 13.8-14.6s-3.8-9.6-13.8-14.6c-9.9-4.9-24.7-8.4-41.2-8.4zm-358.99 2.4c-.29 14.8 15.31 20.7 25.5 23.7c17.9 5.1 41.09 5.1 58.99 0c12.7-3.7 25.4-10.8 25.5-23.7c-1.8 1.2-3.7 2.3-5.7 3.3c-13.2 6.6-30.4 10.3-49.3 10.3c-19.61-1.6-39.88-3.6-54.99-13.6zm205.99.1c-5.8 3.7-12.7 6.6-20.5 8.9c-18 5.1-38.6 6-57.5 2.6v13.7c16.8 3.5 36.7 2.9 52.5-1.6c12.6-3.7 25.4-10.8 25.5-23.6zm66 7.3c-.4 10.3 8 16.1 13.8 19.1c0 0 .1.1.2.1v-12.4c-5.2-1.9-9.9-4.2-14-6.8zM49.01 331.5c-.34 14.6 15.52 20.6 25.5 23.6c17.9 5.1 41.09 5.1 58.99 0c12.6-3.7 25.4-10.8 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.29 6.2-68.99 0c-7.8-2.3-14.7-5.2-20.5-8.9zM177 343v13.6c4.9 1.1 10.2 1.8 15.7 2.2c2-5.3 5.6-9.9 10.2-13.8c-8.7.2-17.5-.5-25.9-2zm87 2c-16.5 0-31.3 3.5-41.2 8.4c-10 5-13.8 10.6-13.8 14.6s3.8 9.6 13.8 14.6c9.9 5 24.7 8.4 41.2 8.4c16.5 0 31.3-3.4 41.2-8.4c10-5 13.8-10.6 13.8-14.6s-3.8-9.6-13.8-14.6c-9.9-4.9-24.7-8.4-41.2-8.4zm89 2.4c-.1 14.8 15.2 20.7 25.5 23.7c17.9 5.1 41.1 5.1 59 0c12.7-3.7 25.4-10.8 25.5-23.7c-15.8 9.6-39.7 13.5-55 13.6c-19.6-1.6-39.9-3.6-55-13.6zM49.01 363.5c-.34 14.6 15.52 20.6 25.5 23.6c17.9 5.1 41.09 5.1 58.99 0c12.6-3.7 25.4-10.8 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.29 6.2-68.99 0c-7.8-2.3-14.7-5.2-20.5-8.9zm303.99 16c-.2 14.7 15.4 20.6 25.5 23.6c17.9 5.1 41.1 5.1 59 0c12.6-3.7 25.4-10.8 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.3 6.2-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm-144 15.9c-.5 6 2.2 10.9 5.5 13.8c4.2 3.6 11 7.3 20 9.9c17.9 5.1 41.1 5.1 59 0c9-2.6 15.8-6.3 20-9.9c4.2-3.6 5.5-6.7 5.5-9.2v-4.6c-1.8 1.2-3.7 2.3-5.7 3.3c-13.2 6.6-30.4 10.3-49.3 10.3s-36.1-3.7-49.3-10.3c-2-1-3.9-2.1-5.7-3.3zm-159.99.1c-.34 14.6 15.52 20.6 25.5 23.6c17.9 5.1 41.09 5.1 58.99 0c12.6-3.7 25.4-10.8 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.29 6.2-68.99 0c-7.8-2.3-14.7-5.2-20.5-8.9zm303.99 16c-.2 14.7 15.4 20.6 25.5 23.6c17.9 5.1 41.1 5.1 59 0c12.6-3.7 25.4-10.8 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.3 6.2-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm-303.99 16c-.34 14.6 15.52 20.6 25.5 23.6c17.9 5.1 41.09 5.1 58.99 0c12.6-3.7 25.4-10.8 25.5-23.6c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.29 6.2-68.99 0c-7.8-2.3-14.7-5.2-20.5-8.9zm159.99 0c-.4 10.3 8 16.1 13.8 19.1c9.9 5 24.7 8.4 41.2 8.4c16.5 0 31.3-3.4 41.2-8.4c9.9-6.2 13.8-8.6 13.8-19.1c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.3 6.2-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm144 16c-.4 10.3 8 16.1 13.8 19.1c9.9 5 24.7 8.4 41.2 8.4c16.5 0 31.3-3.4 41.2-8.4c9.9-6.2 13.8-8.6 13.8-19.1c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.3 6.2-69 0c-7.8-2.3-14.7-5.2-20.5-8.9zm-303.99 16c-.44 10.2 7.88 16.1 13.7 19.1c10 5 24.8 8.4 41.29 8.4c16.5 0 31.3-3.4 41.2-8.4c9.9-6.2 13.8-8.6 13.8-19.1c-5.8 3.7-12.7 6.6-20.5 8.9c-21.7 6.2-47.29 6.2-68.99 0c-7.8-2.3-14.7-5.2-20.5-8.9z"
      />
    </svg>
    """
  end
end
