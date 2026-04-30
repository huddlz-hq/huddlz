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
      owner = generate(user(role: :user))
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

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "You're going to Saturday Soccer" and
          email.to == [{"", to_string(attendee.email)}] and
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

  defp flush_mailbox do
    receive do
      {:email, _} -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
