defmodule DakkaWeb.UserLoginLive do
  use DakkaWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Sign in to account
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Sign up
          </.link>
          for an account now.
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
        <.input field={@form[:username]} type="text" label="Username" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <.link
            href={~p"/users/reset_password"}
            class="text-sm font-semibold text-zinc-200 hover:underline"
          >
            Forgot your password?
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Signing in..." class="w-full">
            Sign in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>

      <div>
        <div class={[
          "justify-center items-center px-2 text-gray-400 flex min-h-[20px] my-6 mx-2",
          "before:h-[1px] before:flex-1 before:bg-gradient-to-r before:from-gray-900 before:to-gray-400",
          "after:h-[1px] after:flex-1 after:bg-gradient-to-l after:from-gray-900 after:to-gray-400"
        ]}>
          <span class="px-4">or</span>
        </div>

        <a
          href={Dakka.Oauth.DiscordClient.log_in_url()}
          class="w-full flex justify-center py-2 px-4 border border-transparent text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          <.icon name="custom-discord-mark-white" class="w-6 h-6 mr-2" /> Sign in with Discord
        </a>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    username = live_flash(socket.assigns.flash, :username)
    form = to_form(%{"username" => username}, as: "user")

    socket =
      socket
      |> assign(form: form)
      |> assign(:page_title, "Log In")

    {:ok, socket, temporary_assigns: [form: form]}
  end
end
