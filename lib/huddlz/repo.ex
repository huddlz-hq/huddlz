defmodule Huddlz.Repo do
  use AshPostgres.Repo,
    otp_app: :huddlz

  @impl true
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "citext", "pg_trgm", "postgis"]
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end

  @impl true
  def init(_, config) do
    config = Keyword.put(config, :types, Huddlz.PostgresTypes)
    {:ok, config}
  end
end
