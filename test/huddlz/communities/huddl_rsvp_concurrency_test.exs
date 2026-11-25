defmodule Huddlz.Communities.HuddlRsvpConcurrencyTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  import Huddlz.Generator

  alias Ecto.Adapters.SQL.Sandbox
  alias Huddlz.{Accounts, Audit, Communities, Notifications, Repo}

  for private? <- [false, true] do
    @private private?
    test "concurrent RSVPs cannot overbook a #{if private?, do: "members-only", else: "public"} huddl" do
      # Committed fixtures let each contender use a separate database connection.
      # Sharing a sandbox connection would serialize queries before row locking.
      Sandbox.unboxed_run(Repo, fn ->
        owner = generate(user(role: :user))
        members = Enum.map(1..2, fn _ -> generate(user(role: :user)) end)
        cleanup_on_exit([owner | members])

        {group, _memberships} =
          generate_group_with_members(
            owner: owner,
            group: [is_public: true],
            members: Enum.map(members, &%{user: &1, role: :member})
          )

        huddl =
          generate(
            huddl(
              group_id: group.id,
              creator_id: owner.id,
              actor: owner,
              event_type: :virtual,
              virtual_link: "https://example.com/meeting",
              is_private: @private,
              max_attendees: 2
            )
          )

        assert Ash.load!(huddl, :rsvp_count, authorize?: false).rsvp_count == 1

        parent = self()

        tasks =
          Enum.map(members, fn member ->
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                %{rows: [[connection_id]]} = Repo.query!("SELECT pg_backend_pid()")
                send(parent, {:ready, self(), connection_id})

                receive do
                  :rsvp -> Communities.rsvp_huddl(huddl, actor: member)
                after
                  5_000 -> flunk("RSVP start signal was not received")
                end
              end)
            end)
          end)

        connection_ids =
          Enum.map(tasks, fn task ->
            pid = task.pid
            assert_receive {:ready, ^pid, connection_id}, 5_000
            connection_id
          end)

        assert length(Enum.uniq(connection_ids)) == 2
        Enum.each(tasks, &send(&1.pid, :rsvp))
        results = Task.await_many(tasks, 10_000)

        assert Enum.count(results, &match?({:ok, _}, &1)) == 1
        assert [{:error, error}] = Enum.filter(results, &match?({:error, _}, &1))
        assert Exception.message(error) =~ "This huddl is full"
        assert Ash.load!(huddl, :rsvp_count, authorize?: false).rsvp_count == 2
      end)
    end
  end

  describe "account release" do
    setup do
      Sandbox.unboxed_run(Repo, fn ->
        owner = generate(user())
        leaving = generate(user())
        waiting = generate(user())
        admin = generate(user(role: :admin))
        cleanup_on_exit([owner, leaving, waiting, admin])

        group = generate(group(actor: owner, owner_id: owner.id, is_public: true))
        huddl = generate(huddl(actor: owner, group_id: group.id, max_attendees: 1))
        Communities.join_waitlist_huddl!(huddl, actor: leaving)
        Communities.join_waitlist_huddl!(huddl, actor: waiting)
        %{owner: owner, leaving: leaving, waiting: waiting, admin: admin, huddl: huddl}
      end)
    end

    test "suspension fills a seat confirmed while the account release is waiting", ctx do
      Sandbox.unboxed_run(Repo, fn ->
        suspend_during_cancellation(ctx, ctx.owner)

        assert [%{waitlisted_at: nil}] =
                 Communities.check_user_rsvp!(ctx.huddl.id, actor: ctx.waiting)

        assert [_] = promotion_notices(ctx.waiting)
      end)
    end

    test "suspension succeeds when the person has already left the waitlist", ctx do
      Sandbox.unboxed_run(Repo, fn ->
        suspend_during_cancellation(ctx, ctx.leaving)

        assert [%{waitlisted_at: %DateTime{}}] =
                 Communities.check_user_rsvp!(ctx.huddl.id, actor: ctx.waiting)

        assert [] = promotion_notices(ctx.waiting)
      end)
    end
  end

  defp suspend_during_cancellation(ctx, cancelling) do
    parent = self()

    # Keep the cancellation uncommitted until suspension has enumerated the
    # person's old spot and is waiting for this transaction's huddl lock.
    {:ok, suspension} =
      Repo.transact(fn ->
        Communities.cancel_rsvp_huddl!(ctx.huddl, actor: cancelling)

        task = Task.async(fn -> suspend_on_own_connection(ctx, parent) end)
        assert_receive {:suspending, pid}, 5_000
        wait_for_lock(pid, System.monotonic_time(:millisecond) + 5_000)
        {:ok, task}
      end)

    assert {:ok, %{suspended_at: %DateTime{}}} = Task.await(suspension, 10_000)
  end

  defp suspend_on_own_connection(ctx, parent) do
    Sandbox.unboxed_run(Repo, fn ->
      %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
      send(parent, {:suspending, pid})
      Accounts.suspend_user(ctx.leaving, "Spam", actor: ctx.admin)
    end)
  end

  defp wait_for_lock(pid, deadline) do
    %{rows: [[blocked?]]} =
      Repo.query!("SELECT pg_backend_pid() = ANY(pg_blocking_pids($1))", [pid])

    unless blocked? do
      assert System.monotonic_time(:millisecond) < deadline,
             "suspension did not wait for cancellation"

      Process.sleep(10)
      wait_for_lock(pid, deadline)
    end
  end

  defp promotion_notices(user) do
    Notifications.list_for_user!(actor: user, page: false)
    |> Enum.filter(&(&1.trigger == "waitlist_promoted"))
  end

  defp cleanup_on_exit(users) do
    ids = Enum.map(users, & &1.id)

    on_exit(fn -> Sandbox.unboxed_run(Repo, fn -> delete_fixtures(ids) end) end)
  end

  defp delete_fixtures(ids) do
    for resource <- Audit.version_resources() do
      Repo.delete_all(from version in resource, where: version.actor_id in ^ids)
    end

    Repo.query!("DELETE FROM oban_jobs WHERE args->>'user_id' = ANY($1)", [ids])
    uuids = Enum.map(ids, &Ecto.UUID.dump!/1)
    Repo.query!("DELETE FROM groups WHERE owner_id = ANY($1::uuid[])", [uuids])
    Repo.query!("DELETE FROM users WHERE id = ANY($1::uuid[])", [uuids])
  end
end
