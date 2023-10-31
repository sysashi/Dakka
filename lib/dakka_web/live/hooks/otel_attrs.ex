defmodule DakkaWeb.Hooks.OtelAttrs do
  require OpenTelemetry.Tracer

  def on_mount(:default, _params, _session, socket) do
    socket.assigns[:current_user]
    |> user_attrs()
    |> OpenTelemetry.Tracer.set_attributes()

    {:cont, socket}
  end

  defp user_attrs(nil), do: []
  defp user_attrs(%Dakka.Accounts.User{} = user), do: [username: user.username]

  ## Plug
  def otel_attrs(conn, _opts) do
    conn.assigns[:current_user]
    |> user_attrs()
    |> OpenTelemetry.Tracer.set_attributes()

    conn
  end
end
