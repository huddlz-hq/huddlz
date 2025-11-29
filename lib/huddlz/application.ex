defmodule Huddlz.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HuddlzWeb.Telemetry,
      Huddlz.Repo,
      {DNSCluster, query: Application.get_env(:huddlz, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:huddlz, :ash_domains),
         Application.fetch_env!(:huddlz, Oban)
       )},
      {Phoenix.PubSub, name: Huddlz.PubSub},
      # Start a worker by calling: Huddlz.Worker.start_link(arg)
      # {Huddlz.Worker, arg},
      # Start to serve requests, typically the last entry
      HuddlzWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :huddlz]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Huddlz.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HuddlzWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
