defmodule DndahWeb.Hooks.Nav do
  # import Phoenix.LiveView
  # use Phoenix.Component

  alias DndahWeb.{
    InventoryLive,
    MarketLive,
    UserSettingsLive,
    OffersLive
  }

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     Phoenix.LiveView.attach_hook(
       socket,
       :active_tab,
       :handle_params,
       &handle_active_tab_params/3
     )}
  end

  def handle_active_tab_params(_params, _url, socket) do
    active_tab =
      case {socket.view, socket.assigns.live_action} do
        {InventoryLive, _} ->
          :inventory

        {MarketLive, _} ->
          :market

        {OffersLive, _} ->
          :offers

        {UserSettingsLive, _} ->
          :account_settings

        {_, _} ->
          nil
      end

    {:cont, Phoenix.Component.assign(socket, :active_tab, active_tab)}
  end
end
