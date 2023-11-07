defmodule Dakka.Workers.DemoListings do
  require Logger

  use Oban.Worker,
    tags: ["demo"],
    unique: [
      period: :infinity,
      states: [:scheduled, :available, :retryable]
    ]

  import Ecto.Query

  alias Dakka.{
    Market,
    Repo
  }

  def start() do
    if demo_mode?() do
      job = new(%{})

      with {:ok, %{conflict?: true}} <- Oban.insert(job) do
        {:error, :job_already_exists}
      else
        {:ok, _} ->
          Logger.info("Starting DemoListings Worker")
          :ok

        error ->
          error
      end
    else
      {:error, :not_in_demo_mode}
    end
  end

  def stop() do
    "Elixir." <> mod = "#{__MODULE__}"

    {_, _} =
      Oban.Job
      |> where(worker: ^mod)
      |> where(state: "scheduled")
      |> Repo.delete_all()

    :ok
  end

  alias Dakka.Accounts.User

  def perform(_job) do
    if demo_mode?() do
      for random_user <- select_random_users() do
        50..300
        |> Enum.random()
        |> Process.sleep()

        Market.generate_random_listing(random_user)
      end

      %{}
      |> new(schedule_in: Enum.random(10..30//5))
      |> Oban.insert()
    else
      :ok
    end
  end

  defp select_random_users() do
    usernames = User |> select([u], u.username) |> Repo.all()
    sample_size = Enum.random(1..3)
    sample = Enum.take_random(usernames, sample_size)

    User
    |> where([u], u.username in ^sample)
    |> Repo.all()
  end

  defp demo_mode?() do
    Application.get_env(:dakka, :demo_mode, false)
  end
end
