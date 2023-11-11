defmodule Dakka.AnnouncementsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dakka.Announcements` context.
  """

  @doc """
  Generate a announcement.
  """
  def announcement_fixture(attrs \\ %{}) do
    {:ok, announcement} =
      attrs
      |> Enum.into(%{
        active: true,
        body: "some body",
        expires_at: ~U[2023-11-10 13:48:00.000000Z],
        kind: Enum.random(~w(info warning error)a),
        title: "some title"
      })
      |> Dakka.Announcements.create_announcement()

    announcement
  end
end
