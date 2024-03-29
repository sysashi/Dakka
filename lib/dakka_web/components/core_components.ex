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
  use DakkaWeb, :verified_routes

  alias Phoenix.LiveView.JS
  import DakkaWeb.Gettext

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
  attr :duration, :integer, default: nil
  attr :clear_key, :any

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(%{kind: kind} = assigns) do
    assigns =
      assigns
      |> assign(:kind, to_string(kind))
      |> assign_new(:clear_key, fn -> assigns.kind end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-hook="Flash"
      phx-click={
        JS.push("lv:clear-flash", value: %{key: @clear_key})
        |> JS.exec("data-hide", to: "##{@id}")
      }
      data-hide={hide("##{@id}")}
      data-clear-key={@clear_key}
      data-duration={@duration}
      role="alert"
      class={[
        "relative w-80 sm:w-96 z-50 border-2 group cursor-pointer",
        @kind == "info" && "bg-green-900 text-emerald-200 border-emerald-400 fill-cyan-200",
        @kind == "error" && "bg-rose-800 text-rose-200 shadow-md border-rose-400 fill-rose-200",
        "animate-disappear"
      ]}
      style={@duration && "--disappear-duration:#{@duration}ms;"}
      {@rest}
    >
      <div class="p-3">
        <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
          <.icon :if={@kind == "info"} name="hero-information-circle-mini" class="h-4 w-4 mt-0.5" />
          <.icon :if={@kind == "error"} name="hero-exclamation-circle-mini" class="h-4 w-4 mt-0.5" />
          <%= @title %>
        </p>
        <p class="mt-2 text-sm leading-5"><%= msg %></p>
      </div>
      <div
        :if={@duration}
        id={"#{@id}-progress"}
        class="flash-progress animate-expand-x h-3 bg-blue-200/20"
        style={"--expand-x-duration:#{@duration}ms;"}
      >
      </div>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-70 group-hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="fixed top-2 right-2">
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
    </div>
    """
  end

  attr :flash, :map

  def flashes(assigns) do
    ~H"""
    <div id="flashes-contrainer" class="text-2xl text-white fixed top-8 right-8 z-50 space-y-4">
      <.flash
        :for={{key, flash} <- Enum.sort_by(@flash, &elem(&1, 0))}
        :if={is_map(flash)}
        id={key}
        kind={flash.kind}
        duration={flash.duration}
        title={flash_title(flash)}
        clear_key={key}
      >
        <%= flash.message %>
      </.flash>

      <.flash
        :for={{kind, flash} <- @flash}
        :if={kind in ~w(info error)}
        kind={kind}
        title={flash_title(kind)}
      >
        <%= flash %>
      </.flash>

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
    </div>
    """
  end

  defp flash_title(%{title: title}), do: title
  defp flash_title(%{kind: kind}), do: kind |> to_string() |> flash_title()
  defp flash_title("info"), do: "Success!"
  defp flash_title("error"), do: "Error!"
  defp flash_title(_), do: nil

  attr :entries, :list, default: []
  attr :class, :any, default: nil

  def announcements(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-2 md:px-0">
      <div class="text-right mt-5 hidden">
        <span
          class="text-zinc-500 italic underline hover:cursor-pointer hover:text-zinc-300"
          phx-click={show(".global-announcement.hidden")}
        >
          Show hidden Announcements
        </span>
      </div>
      <article
        id="global-announcements"
        class={["space-y-4 ", @class]}
        phx-hook="GlobalAnnouncements"
        phx-update="stream"
      >
        <.announcement
          :for={{dom_id, %{announcement: a, hidden: hidden}} <- @entries}
          id={a.id}
          title={a.title}
          kind={a.kind}
          body={a.body}
          dom_id={dom_id}
          hidden={hidden}
        />
      </article>
    </div>
    """
  end

  attr :id, :any
  attr :dom_id, :string, default: nil
  attr :kind, :atom, values: [:info, :warning, :error]
  attr :title, :string, default: nil
  attr :body, :string
  attr :hidden, :boolean, default: false

  def announcement(assigns) do
    ~H"""
    <section
      class={[
        "text-zinc-800 border-4 border-dashed hover:brightness-105 hover:cursor-pointer transition-all relative group",
        @hidden && "hidden",
        @kind == :info && "bg-zinc-400 border-zinc-500",
        @kind == :warning && "bg-amber-600 border-amber-700",
        @kind == :error && "bg-red-500 border-red-600",
        "global-announcement"
      ]}
      id={@dom_id}
    >
      <div class="p-4">
        <h3 :if={@title} class="text-xl">
          <.icon :if={@kind == :info} name="hero-information-circle" class="h-6 w-6" />
          <.icon :if={@kind == :error} name="hero-exclamation-circle" class="h-6 w-6" />
          <.icon :if={@kind == :warning} name="hero-exclamation-triangle" class="h-6 w-6" />
          <%= @title %>
        </h3>
        <div class={[
          "mt-1 py-1",
          "[&_a]:text-blue-600 [&_a]:underline",
          "[&_hr]:text-blue-500 [&_hr]:border-t [&_hr]:border-zinc-500",
          "[&_code]:bg-slate-400 [&_code]:px-[4px] [&_code]:py-[2px] [&_code]:text-slate-900 [&_code]:border [&_code]:border-slate-500"
        ]}>
          <.markdown text={@body} />
        </div>
      </div>
      <div class="absolute top-1 right-1">
        <button
          phx-click={
            JS.dispatch(
              "hide-announcement",
              to: "#global-announcements",
              detail: %{id: @id}
            )
            |> hide("##{@dom_id}")
          }
          type="button"
          class="-m-3 flex-none p-3 opacity-70 group-hover:opacity-90"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark-solid" class="text-zinc-800 h-7 w-7" />
        </button>
      </div>
    </section>
    """
  end

  def markdown(assigns) do
    text = if assigns.text == nil, do: "", else: assigns.text

    markdown_html =
      String.trim(text)
      |> Earmark.as_html!()
      |> Phoenix.HTML.raw()

    assigns = assign(assigns, :markdown, markdown_html)

    ~H"""
    <%= @markdown %>
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
        "disabled:bg-zinc-700 disabled:border-zinc-800 disabled:text-zinc-500",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def button_style(:primary), do: "bg-lime-700 border-green-800 hover:bg-lime-800 text-zinc-50"

  def button_style(:secondary),
    do: "bg-zinc-800 border-zinc-700 hover:bg-green-900 text-zinc-100"

  def button_style(:extra), do: "bg-blue-900 hover:bg-blue-800 border-blue-700 text-zinc-100"

  def button_size(:sm), do: "py-1 px-2"
  def button_size(:md), do: "py-2 px-3"
  def button_size(:xl), do: "py-4 px-5"

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

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

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
          "block w-full border border-zinc-600 bg-zinc-700 text-zinc-50 shadow-sm focus:border-zinc-400 focus:ring-0 appearance-none p-1.5",
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
    <div phx-feedback-for={@name}>
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
        <thead class="text-sm text-left leading-6 text-zinc-200">
          <tr>
            <th :for={col <- @col} class="p-0 pr-6 pb-4 font-normal"><%= col[:label] %></th>
            <th class="relative p-0 pb-4"><span class="sr-only"><%= gettext("Actions") %></span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-800 border-t border-zinc-700 text-sm leading-6 text-zinc-200"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-800">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-800 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-50"]}>
                  <%= render_slot(col, @row_item.(row)) %>
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-800 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-200 hover:text-zinc-300"
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
      <dl class="-my-4 divide-y divide-zinc-600">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none text-zinc-200"><%= item.title %></dt>
          <dd class="text-zinc-300"><%= render_slot(item) %></dd>
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
        class="text-sm font-semibold leading-6 text-zinc-200 hover:text-zinc-300"
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
  attr :rest, :global

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(%{name: "custom-" <> name} = assigns) do
    assigns = assign(assigns, :custom_name, name <> ".svg")

    ~H"""
    <span
      class={[
        @class,
        "bg-current align-middle inline-block"
      ]}
      style={"
      mask-image: url(#{~p"/images/#{@custom_name}"});
      mask-repeat: no-repeat;
      mask-size: contain;
      mask-position: center;
      -webkit-mask-image: url(#{~p"/images/#{@custom_name}"});
      -webkit-mask-repeat: no-repeat;
      -webkit-mask-size: contain;
      -webkit-mask-position: center;
      "}
      {@rest}
    >
    </span>
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
end
