defmodule Huddlz.Communities.HuddlWaitlistTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee

  require Ash.Query

  describe "joining the waitlist" do
    setup :setup_group_and_capped_huddl

    test "user can join the waitlist when the huddl is full", %{
      huddl: huddl,
      member: member,
      waitlister: waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1
      assert waitlist_count(huddl) == 1

      [entry] =
        HuddlAttendee
        |> Ash.Query.for_read(:waitlist_for_huddl, %{huddl_id: huddl.id})
        |> Ash.read!(authorize?: false)

      assert entry.user_id == waitlister.id
      assert %DateTime{} = entry.waitlisted_at
    end

    test "join_waitlist rejects when the huddl is not yet full", %{
      huddl: huddl,
      waitlister: waitlister
    } do
      assert_raise Ash.Error.Invalid, ~r/still has open spots/, fn ->
        huddl
        |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
        |> Ash.update!()
      end
    end

    test "join_waitlist rejects when no capacity is set", %{
      group: group,
      owner: owner,
      waitlister: waitlister
    } do
      uncapped =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Open Huddl",
            description: "No cap",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/000",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      assert_raise Ash.Error.Invalid, ~r/no capacity limit/, fn ->
        uncapped
        |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
        |> Ash.update!()
      end
    end

    test "joining the waitlist twice is a no-op", %{
      huddl: huddl,
      member: member,
      waitlister: waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl = Ash.reload!(huddl)

      huddl
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      assert waitlist_count(huddl) == 1
    end

    test "rsvp_count excludes waitlist entries", %{
      huddl: huddl,
      member: member,
      waitlister: waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1
      assert waitlist_count(huddl) == 1
    end
  end

  describe "leaving the waitlist via cancel_rsvp" do
    setup :setup_group_and_capped_huddl

    test "user can leave the waitlist", %{
      huddl: huddl,
      member: member,
      waitlister: waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      assert waitlist_count(huddl) == 1

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: waitlister)
      |> Ash.update!()

      assert waitlist_count(huddl) == 0
      assert rsvp_count(huddl) == 1
    end

    test "leaving the waitlist does not promote others", %{
      huddl: huddl,
      member: member,
      waitlister: waitlister,
      second_waitlister: second_waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      Enum.each([waitlister, second_waitlister], fn user ->
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: user)
        |> Ash.update!()
      end)

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: waitlister)
      |> Ash.update!()

      # Second waitlister stays on waitlist; only an attendee cancellation
      # frees a real seat.
      assert rsvp_count(huddl) == 1
      assert waitlist_count(huddl) == 1
    end
  end

  describe "promotion on attendee cancellation" do
    setup :setup_group_and_capped_huddl

    test "oldest waitlist entry is promoted when an attendee cancels", %{
      huddl: huddl,
      member: member,
      waitlister: waitlister,
      second_waitlister: second_waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      # Force the second waitlister's timestamp to be later
      Process.sleep(5)

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: second_waitlister)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1
      assert waitlist_count(huddl) == 1

      attendees =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read!(authorize?: false)

      assert [%{user_id: promoted_id}] = attendees
      assert promoted_id == waitlister.id
    end

    test "no promotion when there is no waitlist", %{huddl: huddl, member: member} do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 0
      assert waitlist_count(huddl) == 0
    end
  end

  describe "promotion on capacity increase" do
    setup :setup_group_and_capped_huddl

    test "raising max_attendees promotes waitlisted users in order", %{
      huddl: huddl,
      owner: owner,
      member: member,
      waitlister: waitlister,
      second_waitlister: second_waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      Process.sleep(5)

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: second_waitlister)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1
      assert waitlist_count(huddl) == 2

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:update, %{max_attendees: 3}, actor: owner)
      |> Ash.update!()

      assert rsvp_count(huddl) == 3
      assert waitlist_count(huddl) == 0
    end

    test "lifting cap (nil) promotes everyone on the waitlist", %{
      huddl: huddl,
      owner: owner,
      member: member,
      waitlister: waitlister,
      second_waitlister: second_waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      Enum.each([waitlister, second_waitlister], fn user ->
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: user)
        |> Ash.update!()
      end)

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:update, %{max_attendees: nil}, actor: owner)
      |> Ash.update!()

      assert rsvp_count(huddl) == 3
      assert waitlist_count(huddl) == 0
    end

    test "raising capacity by less than waitlist size promotes only enough to fill", %{
      huddl: huddl,
      owner: owner,
      member: member,
      waitlister: waitlister,
      second_waitlister: second_waitlister
    } do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
      |> Ash.update!()

      Process.sleep(5)

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: second_waitlister)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:update, %{max_attendees: 2}, actor: owner)
      |> Ash.update!()

      assert rsvp_count(huddl) == 2
      assert waitlist_count(huddl) == 1
    end
  end

  defp setup_group_and_capped_huddl(_) do
    owner = generate(user(role: :user))
    member = generate(user(role: :user))
    waitlister = generate(user(role: :user))
    second_waitlister = generate(user(role: :user))

    group =
      Group
      |> Ash.Changeset.for_create(
        :create_group,
        %{name: "Test Group", description: "A test group", is_public: true},
        actor: owner
      )
      |> Ash.create!()

    Enum.each([member, waitlister, second_waitlister], fn user ->
      GroupMember
      |> Ash.Changeset.for_create(
        :add_member,
        %{group_id: group.id, user_id: user.id, role: "member"},
        actor: owner
      )
      |> Ash.create!()
    end)

    huddl =
      Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Capped Huddl",
          description: "A small huddl",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
          event_type: :virtual,
          virtual_link: "https://zoom.us/j/123456",
          is_private: false,
          group_id: group.id,
          creator_id: owner.id,
          max_attendees: 1
        },
        actor: owner
      )
      |> Ash.create!()

    %{
      owner: owner,
      member: member,
      waitlister: waitlister,
      second_waitlister: second_waitlister,
      group: group,
      huddl: huddl
    }
  end

  defp rsvp_count(huddl) do
    huddl |> Ash.reload!() |> Ash.load!(:rsvp_count, authorize?: false) |> Map.get(:rsvp_count)
  end

  defp waitlist_count(huddl) do
    huddl
    |> Ash.reload!()
    |> Ash.load!(:waitlist_count, authorize?: false)
    |> Map.get(:waitlist_count)
  end
end
