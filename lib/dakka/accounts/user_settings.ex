defmodule Dakka.Accounts.UserSettings do
  use Ecto.Schema
  import Ecto.Changeset

  defmodule Display do
    use Ecto.Schema

    embedded_schema do
      field :show_item_icon, :boolean, default: false
      field :show_item_flavor_text, :boolean, default: true
      field :show_item_properties, :boolean, default: true
    end

    def changeset(display_settings, attrs) do
      display_settings
      |> Ecto.Changeset.cast(attrs, [
        :show_item_icon,
        :show_item_properties,
        :show_item_flavor_text
      ])
    end
  end

  defmodule Notification do
    use Ecto.Schema

    embedded_schema do
      field :action, :string
      field :enabled, :boolean, default: true
    end

    def changeset(notification_setting, attrs) do
      notification_setting
      |> Ecto.Changeset.cast(attrs, [:action, :enabled])
      |> Ecto.Changeset.validate_required([:action, :enabled])
    end
  end

  alias __MODULE__.{Display, Notification}
  alias Dakka.Accounts.UserNotification

  embedded_schema do
    embeds_one :display, Display, on_replace: :update
    embeds_many :notifications, Notification, on_replace: :delete
  end

  def changeset(settings, attrs \\ %{}) do
    settings
    |> cast(attrs, [])
    |> cast_embed(:display)
    |> cast_embed(:notifications)
  end

  def default() do
    %__MODULE__{
      display: %Display{},
      notifications: Enum.map(UserNotification.actions(), &%Notification{action: "#{&1}"})
    }
  end

  def change_default_settings(attrs \\ %{}) do
    changeset(default(), attrs)
  end

  def app_notification_enabled?(%__MODULE__{} = settings, action) when is_atom(action) do
    %{notifications: notifications} = settings
    action = Atom.to_string(action)
    Enum.find_value(notifications, false, &(&1.action == action && &1.enabled))
  end

  def app_notification_enabled?(nil, action), do: app_notification_enabled?(default(), action)
end
