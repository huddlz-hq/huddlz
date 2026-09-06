defmodule Huddlz.Communities.HuddlRsvpConcurrencyTest do
  use ExUnit.Case, async: false

  import Huddlz.Generator

  alias Ecto.Adapters.SQL.Sandbox
  alias Huddlz.Communities
  alias Huddlz.Repo

  for private? <- [false, true] do
    @private private?
    test "concurrent RSVPs cannot overbook a #{if private?, do: "members-only", else: "public"} huddl" do
      # Committed fixtures let each contender use a separate database connection.
      # Sharing a sandbox connection would serialize queries before row locking.
      Sandbox.unboxed_run(Repo, fn ->
        owner = generate(user(role: :user))
        members = Enum.map(1..2, fn _ -> generate(user(role: :user)) end)
        user_ids = Enum.map([owner | members], & &1.id)

        on_exit(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            Repo.query!("DELETE FROM oban_jobs WHERE args->>'user_id' = ANY($1)", [user_ids])

            ids = Enum.map(user_ids, &Ecto.UUID.dump!/1)
            Repo.query!("DELETE FROM groups WHERE owner_id = ANY($1::uuid[])", [ids])
            Repo.query!("DELETE FROM users WHERE id = ANY($1::uuid[])", [ids])
          end)
        end)

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
end
