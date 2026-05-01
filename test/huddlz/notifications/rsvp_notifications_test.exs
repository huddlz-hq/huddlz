defmodule Huddlz.Notifications.RsvpNotificationsTest do
  @moduledoc """
  Integration coverage for the E-series RSVP notifications (see
  `docs/notifications.md` § E). Exercises the `Huddl.:rsvp` and
  `Huddl.:cancel_rsvp` actions end-to-end through the Oban worker
  and asserts the resulting Swoosh email.
  """

  use Huddlz.DataCase, async: false
  use Oban.Testing, repo: Huddlz.Repo

  import Swoosh.TestAssertions
  require Ash.Query

  alias Huddlz.Notifications.DeliverWorker

  describe "E3: rsvp_confirmation" do
    test "emails the rsvper themselves with an .ics attachment" do
      # Setup: actor IS the sole owner of the group, so E1's recipient
      # set (owner+organizers minus actor) is empty and only E3 fires.
      # This keeps the test focused on E3's distinguishing properties
      # (subject + .ics attachment).
      owner = generate(user(role: :user, display_name: "Owner"))

      group =
        generate(
          group(
            name: "Pickup Sports",
            slug: "pickup-sports",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      huddl =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: owner)
      |> Ash.update!()

      assert %{failure: 0} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "You're going to Saturday Soccer" and
          email.to == [{"", to_string(owner.email)}] and
          Enum.any?(email.attachments, &(&1.content_type == "text/calendar"))
      end)
    end

    test "does not fire on duplicate RSVP" do
      owner = generate(user(role: :user))
      attendee = generate(user())

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      refute_enqueued(worker: DeliverWorker)
    end

    test "does not fire when capacity is rejected" do
      owner = generate(user(role: :user))
      first = generate(user())
      second = generate(user())

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            max_attendees: 1
          )
        )

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: first)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      assert_raise Ash.Error.Invalid, ~r/full/, fn ->
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{}, actor: second)
        |> Ash.update!()
      end

      refute_enqueued(worker: DeliverWorker)
    end
  end

  describe "E1: rsvp_received" do
    test "emails the group owner and every organizer (deduped, actor excluded)" do
      owner = generate(user(role: :user, display_name: "Owner"))
      organizer_a = generate(user(display_name: "Org A"))
      organizer_b = generate(user(display_name: "Org B"))
      attendee = generate(user(display_name: "Attendee"))

      group =
        generate(
          group(
            name: "Pickup Sports",
            slug: "pickup-sports",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      for org <- [organizer_a, organizer_b] do
        generate(
          group_member(group_id: group.id, user_id: org.id, role: :organizer, actor: owner)
        )
      end

      huddl =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      # Per-recipient assertions below cover what was sent. Drain
      # asserts no jobs failed.
      assert %{failure: 0} = Oban.drain_queue(queue: :notifications)

      for recipient <- [owner, organizer_a, organizer_b] do
        assert_email_sent(fn email ->
          email.subject == "Attendee RSVPd to Saturday Soccer" and
            email.to == [{"", to_string(recipient.email)}] and
            email.html_body =~ "/groups/pickup-sports/huddlz/#{huddl.id}"
        end)
      end
    end

    test "actor who is also an organizer is excluded from E1 but still receives E3" do
      owner = generate(user(role: :user))
      organizer = generate(user(display_name: "Self-RSVPing Organizer"))

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      huddl =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: organizer)
      |> Ash.update!()

      assert %{failure: 0} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "Self-RSVPing Organizer RSVPd to Saturday Soccer" and
          email.to == [{"", to_string(owner.email)}]
      end)

      assert_email_sent(fn email ->
        email.subject == "You're going to Saturday Soccer" and
          email.to == [{"", to_string(organizer.email)}]
      end)
    end

    test "does not fire when the actor is the only owner/organizer (recipient set is empty)" do
      owner = generate(user(role: :user))

      group =
        generate(group(name: "Solo Group", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: owner)
      |> Ash.update!()

      # Only E3 to the owner. No E1 since owner is the actor.
      assert %{failure: 0} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "You're going to #{huddl.title}" and
          email.to == [{"", to_string(owner.email)}]
      end)
    end
  end

  describe "E2: rsvp_cancelled" do
    test "emails the group owner and every organizer (deduped, actor excluded)" do
      owner = generate(user(role: :user, display_name: "Owner"))
      organizer = generate(user(display_name: "Organizer"))
      attendee = generate(user(display_name: "Attendee"))

      group =
        generate(
          group(
            name: "Pickup Sports",
            slug: "pickup-sports",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      huddl =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: attendee)
      |> Ash.update!()

      # Owner + organizer get E2. There is no E4 confirmation to the
      # actor (the spec explicitly skips it).
      assert %{failure: 0} = Oban.drain_queue(queue: :notifications)

      for recipient <- [owner, organizer] do
        assert_email_sent(fn email ->
          email.subject == "Attendee cancelled their RSVP to Saturday Soccer" and
            email.to == [{"", to_string(recipient.email)}] and
            email.html_body =~ "/groups/pickup-sports/huddlz/#{huddl.id}"
        end)
      end
    end

    test "does not fire when cancelling a nonexistent RSVP" do
      owner = generate(user(role: :user))
      attendee = generate(user())

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      # Attendee never RSVPd. cancel_rsvp is a no-op but the action still
      # succeeds; no email should fire.
      huddl
      |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: attendee)
      |> Ash.update!()

      refute_enqueued(worker: DeliverWorker)
    end

    test "actor who is also an organizer is excluded from E2" do
      owner = generate(user(role: :user))
      organizer = generate(user(display_name: "Self-cancelling Organizer"))

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      huddl =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: organizer)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: organizer)
      |> Ash.update!()

      # Only owner gets E2. Organizer is the actor — excluded.
      assert %{failure: 0} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.to == [{"", to_string(owner.email)}] and
          email.subject == "Self-cancelling Organizer cancelled their RSVP to Saturday Soccer"
      end)
    end
  end

  defp flush_mailbox do
    receive do
      {:email, _} -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
