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
      {Finch, name: Jok3r.Finch},
      Jok3rWeb.Endpoint,
      Jok3r.Rooms.Admin
    ]

    opts = [strategy: :one_for_one, name: Jok3r.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Jok3rWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
