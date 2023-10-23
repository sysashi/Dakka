defmodule DakkaWeb.Hooks.MarketPresence do
  alias DakkaWeb.Presence

  def on_mount(:default, _params, _session, socket) do
    scope = socket.assigns.scope

    if scope.current_user do
      Presence.track(scope)
    end

    {:cont, socket}
  end
end
