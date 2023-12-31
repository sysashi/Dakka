defmodule Dakka.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    setup_otel()
    Logger.add_handlers(:dakka)

    children = [
      # Start the Ecto repository
      Dakka.Repo,
      # Start the Telemetry supervisor
      DakkaWeb.Telemetry,
      # Start Oban
      {Oban, Application.fetch_env!(:dakka, Oban)},
      # Simple DNS cluster
      {DNSCluster, query: dns_cluster_query()},
      # Start the PubSub system
      {Phoenix.PubSub, name: Dakka.PubSub},
      # Start Presence
      DakkaWeb.Presence,
      # Start Finch
      {Finch, name: Dakka.Finch},
      # Start the Endpoint (http/https)
      DakkaWeb.Endpoint,
      # Start a worker by calling: Dakka.Worker.start_link(arg)
      # {Dakka.Worker, arg}
      {Task, fn -> Dakka.Workers.DemoListings.start() end}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dakka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DakkaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp setup_otel() do
    OpentelemetryEcto.setup([:dakka, :repo])
    OpentelemetryPhoenix.setup()
    OpentelemetryOban.setup()
  end

  defp dns_cluster_query() do
    Application.get_env(:dakka, :dns_cluster_query, nil) || :ignore
  end
end
