defmodule DakkaWeb.ImportItemLive do
  use DakkaWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mt-10 space-y-4">
      <form
        id="upload-form"
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="flex gap-4"
      >
        <label
          class={[
            "cursor-pointer",
            "bg-zinc-800 border-zinc-700 hover:bg-green-900 text-zinc-100",
            "py-2 px-3",
            "border text-sm flex justify-center items-center",
            "phx-submit-loading:opacity-75",
            "font-semibold leading-6 active:text-white/80",
            "transition-colors duration-100"
          ]}
          for={@uploads.item.ref}
        >
          Choose Image <.icon name="hero-photo" class="w-6 h-6 text-zinc-100 ml-2" />
        </label>
        <.live_file_input upload={@uploads.item} class="hidden" />
        <.button disabled={Enum.empty?(@uploads.item.entries)} type="submit">Upload</.button>
      </form>

      <%!-- use phx-drop-target with the upload ref to enable file drag and drop --%>
      <%!-- render each item entry --%>
      <div :if={Enum.empty?(@uploads.item.entries)} class="relative">
        <img src={~p"/images/item_placeholder_bw.webp"} />
        <div class="absolute inset-0 h-full w-full flex text-zinc-200 justify-center items-center text-2xl">
          Select an image first
        </div>
      </div>
      <%= for entry <- @uploads.item.entries do %>
        <article class="upload-entry text-right">
          <figure>
            <.live_img_preview entry={entry} />
          </figure>

          <%!-- entry.progress will update automatically for in-flight entries --%>
          <div class="flex items-center justify-center">
            <progress class="bg-zinc-500 rounded-sm mt-4" value={entry.progress} max="100">
              <%= entry.progress %>%
            </progress>

            <%!-- a regular click event whose handler will invoke Phoenix.LiveView.cancel_upload/3 --%>
            <button
              class="mt-3 ml-2"
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              aria-label="cancel"
              phx-target={@myself}
            >
              <.icon name="hero-x-circle" class="text-red-400 h-5 w-5" />
            </button>
          </div>

          <%!-- Phoenix.Component.upload_errors/2 returns a list of error atoms --%>
          <%= for err <- upload_errors(@uploads.item, entry) do %>
            <p class="alert alert-danger"><%= error_to_string(err) %></p>
          <% end %>
        </article>
      <% end %>

      <%!-- Phoenix.Component.upload_errors/1 returns a list of error atoms --%>
      <%= for err <- upload_errors(@uploads.item) do %>
        <p class="alert alert-danger"><%= error_to_string(err) %></p>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    socket =
      socket
      |> assign(:uploaded_images, [])
      |> allow_upload(:item, accept: ~w(.jpeg .jpg .png .webp), max_entries: 1)

    {:ok, socket}
  end

  def handle_event("validate", %{}, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{}, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :item, fn %{path: path}, _entry ->
        with {:ok, item_base, data} <- Dakka.Game.Import.from_image(path) do
          socket.assigns.on_item_import.(item_base, data)
        end

        {:ok, path}
      end)

    socket =
      socket
      |> update(:uploaded_images, &(&1 ++ uploaded_files))
      |> push_patch(to: socket.assigns.patch)

    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :item, ref)}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
