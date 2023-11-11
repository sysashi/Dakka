defmodule DakkaWeb.Hooks.Announcements do
  import Phoenix.LiveView

  alias Dakka.Announcements

  alias Dakka.Announcements.Events.{
    AnnouncementActivated,
    AnnouncementDeactivated,
    AnnouncementUpdated
  }

  def on_mount(:default, _params, _session, socket) do
    # Don't load announcements if socket is not connected,
    # otherwise already hidden ones derived from connect_params
    # will always be empty, which will force render all and "jumping" markup
    socket =
      if connected?(socket) do
        Announcements.subscribe()

        socket
        |> load_announcements()
        |> attach_hook(
          :announcements_handler,
          :handle_info,
          &announcements_handler/2
        )
      else
        stream(socket, :active_announcements, [])
      end

    {:cont, socket}
  end

  def load_announcements(socket) do
    hidden_by_client = get_hidden(socket)
    active_announcements = Announcements.list_active_announcements()

    {announcement_records, obsolete_hidden} =
      Enum.map_reduce(active_announcements, hidden_by_client, fn a, hidden ->
        {announcement_hidden?, hidden_rest} = Map.pop(hidden, "#{a.id}", false)
        {to_record(a, announcement_hidden?), hidden_rest}
      end)

    socket
    |> stream(:active_announcements, announcement_records)
    |> push_event("clear-hidden-announcements", %{ids: Map.keys(obsolete_hidden)})
  end

  defp announcements_handler({Announcements, event}, socket) do
    {:halt, handle_announcement_event(socket, event)}
  end

  defp announcements_handler(_msg, socket) do
    {:cont, socket}
  end

  defp handle_announcement_event(socket, %AnnouncementActivated{} = event) do
    stream_insert(socket, :active_announcements, to_record(event.announcement), at: 0)
  end

  defp handle_announcement_event(socket, %AnnouncementDeactivated{} = event) do
    stream_delete(socket, :active_announcements, to_record(event.announcement))
  end

  defp handle_announcement_event(socket, %AnnouncementUpdated{} = event) do
    stream_insert(socket, :active_announcements, to_record(event.announcement))
  end

  defp to_record(a, hidden \\ false) do
    %{
      id: a.id,
      announcement: a,
      hidden: to_bool(hidden)
    }
  end

  defp get_hidden(socket) do
    case get_connect_params(socket) do
      %{"hidden_announcements" => hidden} when is_map(hidden) ->
        hidden

      _ ->
        %{}
    end
  end

  defp to_bool(bool) when is_boolean(bool), do: bool
  defp to_bool(nil), do: false
  defp to_bool(_), do: true
end
