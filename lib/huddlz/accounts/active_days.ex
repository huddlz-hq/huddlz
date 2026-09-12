defmodule Huddlz.Accounts.ActiveDays do
  @moduledoc """
  Marks a person as active today, once. The browser pipeline, the API
  pipelines and the LiveView mount hook all call `mark/2` on every request
  that carries a signed-in person; a small in-memory note of who has
  already been recorded on which day keeps that to one database write per
  person per day. The row itself is an upsert, so another node or a
  restart only repeats a harmless write.

  While an administrator is viewing huddlz as someone, the administrator
  is the one using huddlz, so the mark is theirs.
  """

  use GenServer

  require Logger

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User
  alias Huddlz.Admin.Impersonation

  @table :huddlz_active_days

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  @doc """
  Record that the person used huddlz on the UTC day of `now`. Anything
  that is not a signed-in person is ignored.
  """
  def mark(user, now \\ DateTime.utc_now())

  def mark(%User{} = user, now) do
    person = person(user)
    day = DateTime.to_date(now)

    if seen?(person.id, day) do
      :ok
    else
      case Accounts.record_active_day(%{day: day}, actor: person) do
        {:ok, _active_day} ->
          :ets.insert(@table, {person.id, day})
          :ok

        {:error, error} ->
          Logger.warning("could not record an active day: #{Exception.message(error)}")
          :error
      end
    end
  end

  def mark(_other, _now), do: :ok

  defp seen?(user_id, day) do
    case :ets.lookup(@table, user_id) do
      [{^user_id, ^day}] -> true
      _ -> false
    end
  end

  defp person(%User{__metadata__: %{impersonation: %Impersonation{admin: %User{} = admin}}}),
    do: admin

  defp person(%User{__metadata__: %{impersonation: %Impersonation{admin_id: admin_id}}}),
    do: Ash.get!(User, admin_id, authorize?: false)

  defp person(%User{} = user), do: user
end
