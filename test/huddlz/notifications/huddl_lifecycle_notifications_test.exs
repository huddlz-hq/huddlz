defmodule Huddlz.Notifications.HuddlLifecycleNotificationsTest do
  @moduledoc """
  Integration coverage for the C-series and D-series huddl-lifecycle
  notifications (see `docs/notifications.md`). Exercises each Ash
  action end-to-end through the Oban worker and asserts the resulting
  Swoosh email.
  """

  use Huddlz.DataCase, async: false
  use Oban.Testing, repo: Huddlz.Repo

  import Swoosh.TestAssertions
  require Ash.Query

  alias Huddlz.Notifications.DeliverWorker

  describe "C3: huddl_cancelled" do
    test "emails every non-actor RSVP when the huddl is destroyed" do
      owner = generate(user(role: :user, display_name: "Group Owner"))
      attendee_a = generate(user(display_name: "Attendee A"))
      attendee_b = generate(user(display_name: "Attendee B"))

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

      for attendee <- [attendee_a, attendee_b] do
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
        |> Ash.update!()
      end

      # Drain any prior jobs (e.g. from RSVP) so the assertions below
      # only see the cancellation emails.
      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
      |> Ash.destroy!()

      assert %{success: 2} = Oban.drain_queue(queue: :notifications)

      for recipient <- [attendee_a, attendee_b] do
        assert_email_sent(fn email ->
          email.subject == "Cancelled: Saturday Soccer" and
            email.to == [{"", to_string(recipient.email)}] and
            email.html_body =~ "Pickup Sports" and
            email.html_body =~ "/groups/pickup-sports"
        end)
      end
    end

    test "skips the actor (the owner cancelling) even if they had RSVPd" do
      owner = generate(user(role: :user, display_name: "Group Owner"))
      attendee = generate(user(display_name: "Attendee"))

      group =
        generate(group(name: "Solo Group", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Cancelled Meetup",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      # Both the owner and an attendee RSVP.
      for u <- [owner, attendee] do
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{}, actor: u)
        |> Ash.update!()
      end

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
      |> Ash.destroy!()

      # Only the non-actor RSVP gets emailed (the success count proves
      # the owner's job was never enqueued).
      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.to == [{"", to_string(attendee.email)}]
      end)
    end

    test "no notifications when the huddl had no RSVPs" do
      owner = generate(user(role: :user))

      group =
        generate(group(name: "Empty Group", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: owner)
      |> Ash.destroy!()

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
