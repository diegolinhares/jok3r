defmodule Jok3r.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Jok3rWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:jok3r, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Jok3r.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Jok3r.Finch},
      # Start a worker by calling: Jok3r.Worker.start_link(arg)
      # {Jok3r.Worker, arg},
      # Start to serve requests, typically the last entry
      Jok3rWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jok3r.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Jok3rWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
