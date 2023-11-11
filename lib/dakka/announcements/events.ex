defmodule Dakka.Announcements.Events do
  defmodule AnnouncementActivated do
    defstruct announcement: nil
  end

  defmodule AnnouncementDeactivated do
    defstruct announcement: nil
  end

  defmodule AnnouncementUpdated do
    defstruct announcement: nil
  end
end
