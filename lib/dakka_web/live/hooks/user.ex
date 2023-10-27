defmodule DakkaWeb.Hooks.User do
  import Phoenix.LiveView
  import Phoenix.Component

  alias Dakka.Accounts
  alias Dakka.Accounts.UserNotification
  alias Dakka.Accounts.Events.UserSettingsUpdated

  @names [:app_settings, :notifications]

  def on_mount({name, opts}, params, session, socket) when name in @names do
    mount({name, opts}, params, session, socket)
  end

  def on_mount(name, params, session, socket) when name in @names do
    mount({name, []}, params, session, socket)
  end

  defp mount({:notifications, opts}, _params, _session, socket) do
    %{scope: scope} = socket.assigns
    subscribe? = Keyword.get(opts, :subscribe?, true)

    if scope.current_user && connected?(socket) do
      subscribe? && Accounts.subscribe(scope)

      notifications_count =
        Accounts.count_notifications(
          scope,
          status: :unread,
          actions: [
            :offer_accepted,
            :offer_declined,
            :offer_cancelled,
            :offer_created
          ]
        )

      socket =
        socket
        |> attach_hook(
          :user_notifications_handler,
          :handle_info,
          &handle_user_notification/2
        )
        |> assign(:offers_unread_notifications_count, notifications_count)

      {:cont, socket}
    else
      {:cont, assign(socket, :offers_unread_notifications_count, 0)}
    end
  end

  defp mount({:app_settings, opts}, _params, _session, socket) do
    %{scope: scope} = socket.assigns
    subscribe? = Keyword.get(opts, :subscribe?, true)

    if scope.current_user && connected?(socket) do
      subscribe? && Accounts.subscribe(scope)

      socket =
        socket
        |> attach_hook(
          :user_settings_handler,
          :handle_info,
          &handle_settings_update/2
        )
        |> assign(:settings, scope.current_user.settings)

      {:cont, socket}
    else
      {:cont, assign(socket, :settings, Accounts.UserSettings.default())}
    end
  end

  ## Notifications

  defp handle_user_notification({Accounts, %UserNotification{} = notification}, socket) do
    %{settings: settings} = socket.assigns

    notify_browser? =
      Accounts.UserSettings.app_notification_enabled?(settings, notification.action)

    if socket.view != DakkaWeb.OffersLive do
      socket =
        socket
        |> update(:offers_unread_notifications_count, &(&1 + 1))
        |> push_event("highlight", %{id: "offers-unread-notifications-count"})

      socket =
        if notify_browser? do
          push_event(
            socket,
            "browser-notify",
            UserNotification.to_browser_notification(notification)
          )
        else
          socket
        end

      {:halt, socket}
    else
      {:halt, socket}
    end
  end

  defp handle_user_notification({:read_offers_notifications, count}, socket) when count >= 0 do
    %{offers_unread_notifications_count: current_count} = socket.assigns
    new_count = max(current_count - count, 0)
    {:halt, assign(socket, :offers_unread_notifications_count, new_count)}
  end

  defp handle_user_notification(_message, socket) do
    {:cont, socket}
  end

  ## Settings

  defp handle_settings_update({Accounts, %UserSettingsUpdated{} = event}, socket) do
    {:halt, assign(socket, :settings, event.user.settings)}
  end

  defp handle_settings_update(_message, socket) do
    {:cont, socket}
  end
end
