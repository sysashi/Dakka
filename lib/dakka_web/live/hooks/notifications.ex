defmodule DakkaWeb.Hooks.Notifications do
  # Currently it's highly specific to offers
  # basically a prototype, as with the rest of the system

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3, update: 3]

  alias Dakka.Accounts
  alias Dakka.Accounts.UserNotification

  def on_mount(:default, _params, _session, socket) do
    scope = socket.assigns.scope

    if scope.current_user && connected?(socket) do
      Dakka.Accounts.subscribe(scope)

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
          :notification_handler,
          :handle_info,
          &handle_notification/2
        )
        |> assign(:offers_unread_notifications_count, notifications_count)

      {:cont, socket}
    else
      {:cont, assign(socket, :offers_unread_notifications_count, 0)}
    end
  end

  defp handle_notification({Accounts, %UserNotification{} = notification}, socket) do
    if socket.view != DakkaWeb.OffersLive do
      socket =
        socket
        |> update(:offers_unread_notifications_count, &(&1 + 1))
        |> push_event("highlight", %{id: "offers-unread-notifications-count"})
        |> push_event("browser-notify", UserNotification.to_browser_notification(notification))

      {:halt, socket}
    else
      {:halt, socket}
    end
  end

  defp handle_notification({:read_offers_notifications, count}, socket) when count >= 0 do
    %{offers_unread_notifications_count: current_count} = socket.assigns
    new_count = max(current_count - count, 0)
    {:halt, assign(socket, :offers_unread_notifications_count, new_count)}
  end

  defp handle_notification(_message, socket) do
    {:cont, socket}
  end
end
