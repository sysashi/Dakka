defmodule DakkaWeb.PageController do
  use DakkaWeb, :controller

  plug :put_required_assigns

  def credits(conn, _params) do
    render(conn, :credits)
  end

  defp put_required_assigns(conn, _opts) do
    scope = Dakka.Scope.for_user(conn.assigns.current_user)

    conn
    |> assign(:scope, scope)
    |> assign(:offers_unread_notifications_count, notifications_count(scope))
    |> assign(:active_tab, nil)
  end

  defp notifications_count(%{current_user: nil}), do: 0

  defp notifications_count(scope) do
    Dakka.Accounts.count_notifications(
      scope,
      status: :unread,
      actions: [
        :offer_accepted,
        :offer_declined,
        :offer_cancelled,
        :offer_created
      ]
    )
  end
end
