defmodule Dndah.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      DndahWeb.Telemetry,
      # Start the Ecto repository
      Dndah.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Dndah.PubSub},
      # Start Presence
      DndahWeb.Presence,
      # Start Finch
      {Finch, name: Dndah.Finch},
      # Start the Endpoint (http/https)
      DndahWeb.Endpoint
      # Start a worker by calling: Dndah.Worker.start_link(arg)
      # {Dndah.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dndah.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DndahWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
