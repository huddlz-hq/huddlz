defmodule Huddlz.Health do
  @moduledoc """
  Readiness checks for dependencies required to serve huddlz traffic.
  """

  alias Ecto.Adapters.SQL

  require Logger

  @spec check() :: :ok | :error
  def check do
    with :ok <- check_database(), do: check_oban()
  end

  defp check_database do
    case SQL.query(Huddlz.Repo, "SELECT 1", [], timeout: 2_000) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        log_failure("database", reason)
    end
  catch
    :exit, reason -> log_failure("database", reason)
  end

  defp check_oban do
    case Oban.whereis(Oban) do
      pid when is_pid(pid) ->
        :ok

      nil ->
        log_failure("Oban", "process is not running")
    end
  end

  defp log_failure(dependency, reason) do
    Logger.warning("Readiness #{dependency} check failed: #{inspect(reason)}")
    :error
  end
end
