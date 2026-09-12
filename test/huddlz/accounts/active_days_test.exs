defmodule Huddlz.Accounts.ActiveDaysTest do
  use Huddlz.DataCase, async: false

  alias Huddlz.Accounts.{ActiveDay, ActiveDays, User}

  @moduletag :active_day_writes

  test "a failed write is retried on the next request" do
    person = generate(user())
    Repo.delete_all(from(user in User, where: user.id == ^person.id))

    assert ActiveDays.mark(person) == :error
    Ash.Seed.seed!(User, Map.take(person, [:id, :email, :display_name, :role, :confirmed_at]))
    assert ActiveDays.mark(person) == :ok
    assert Ash.count!(ActiveDay, authorize?: false) == 1
  end

  test "the next UTC date is recorded even after yesterday was cached" do
    person = generate(user())

    assert ActiveDays.mark(person, ~U[2026-09-12 23:59:59Z]) == :ok
    assert ActiveDays.mark(person, ~U[2026-09-13 00:00:00Z]) == :ok
    assert ActiveDays.mark(person, ~U[2026-09-13 00:00:01Z]) == :ok

    days = ActiveDay |> Ash.read!(authorize?: false) |> Enum.map(& &1.day) |> Enum.sort(Date)
    assert days == [~D[2026-09-12], ~D[2026-09-13]]
  end

  test "concurrent first requests share one successful database write" do
    person = generate(user())
    observer = self()
    handler = {__MODULE__, make_ref()}

    :telemetry.attach(
      handler,
      [:huddlz, :repo, :query],
      &__MODULE__.hold_active_write/4,
      observer
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    first = Task.async(fn -> ActiveDays.mark(person) end)
    assert_receive {:active_write, writer}, 1_000
    second = Task.async(fn -> ActiveDays.mark(person) end)

    try do
      refute_receive {:active_write, _}, 250
    after
      send(writer, :release_write)
      send(second.pid, :release_write)
    end

    assert Task.await(first) == :ok
    assert Task.await(second) == :ok
    refute_receive {:active_write, _}
    assert Ash.count!(ActiveDay, authorize?: false) == 1
  end

  # Hold the first caller after SQL succeeds but before it can cache success.
  # A second request must wait, rather than issuing its own upsert.
  def hold_active_write(_name, _measurements, metadata, observer) do
    if String.starts_with?(metadata.query, "INSERT INTO \"active_days\"") do
      send(observer, {:active_write, self()})

      receive do
        :release_write -> :ok
      after
        5_000 -> raise "active-day write was not released"
      end
    end
  end
end
