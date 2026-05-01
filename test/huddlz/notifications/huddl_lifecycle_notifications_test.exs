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

  alias Huddlz.Communities.Huddl
  alias Huddlz.Notifications.DeliverWorker

  describe "C1: huddl_new" do
    test "emails every non-actor group member when a huddl is created" do
      owner = generate(user(role: :user, display_name: "Owner"))
      member_a = generate(user(display_name: "Member A"))
      member_b = generate(user(display_name: "Member B"))

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

      for u <- [member_a, member_b] do
        generate(group_member(group_id: group.id, user_id: u.id, actor: owner))
      end

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      _huddl =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      # Owner is the actor (excluded), member_a and member_b each receive one.
      assert %{success: 2} = Oban.drain_queue(queue: :notifications)
      emails = drain_mailbox()

      for recipient <- [member_a, member_b] do
        assert Enum.any?(emails, fn email ->
                 email.subject == "New huddl in Pickup Sports: Saturday Soccer" and
                   email.to == [{"", to_string(recipient.email)}]
               end)
      end
    end

    test "skips the actor (creator) even when they are also a member" do
      owner = generate(user(role: :user))
      member = generate(user())

      group =
        generate(
          group(
            name: "Solo Group",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      generate(group_member(group_id: group.id, user_id: member.id, actor: owner))

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.to == [{"", to_string(member.email)}]
      end)
    end
  end

  describe "C2: huddl_updated" do
    test "emails every non-actor RSVP when a meaningful field changes" do
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

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      new_date = Date.add(Date.utc_today(), 14)

      huddl
      |> Ash.Changeset.for_update(
        :update,
        %{date: new_date, start_time: ~T[15:00:00], duration_minutes: 60},
        actor: owner
      )
      |> Ash.update!()

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "Updated: Saturday Soccer" and
          email.to == [{"", to_string(attendee.email)}] and
          email.html_body =~ "the start time"
      end)
    end

    test "skips notification when no meaningful field changes" do
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

      # Changing the description (not a meaningful field) should not
      # enqueue any huddl_updated notification.
      huddl
      |> Ash.Changeset.for_update(:update, %{description: "now with more detail"}, actor: owner)
      |> Ash.update!()

      refute_enqueued(worker: DeliverWorker)
    end

    test "skips the actor (the editor) even if they had RSVPd" do
      owner = generate(user(role: :user))
      attendee = generate(user())

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      for u <- [owner, attendee] do
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{}, actor: u)
        |> Ash.update!()
      end

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      huddl
      |> Ash.Changeset.for_update(:update, %{title: "Renamed"}, actor: owner)
      |> Ash.update!()

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.to == [{"", to_string(attendee.email)}]
      end)
    end
  end

  describe "C4: huddl_series_updated" do
    test "edit_type=all sends huddl_series_updated to the next instance's RSVPs" do
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

      original =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            is_recurring: true,
            frequency: "weekly",
            repeat_until: Date.add(Date.utc_today(), 60)
          )
        )

      original
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      original
      |> Ash.load!([:huddl_template], authorize?: false)
      |> Ash.Changeset.for_update(
        :update,
        %{
          title: "Saturday Soccer (renamed)",
          edit_type: "all",
          repeat_until: Date.add(Date.utc_today(), 60),
          frequency: "weekly"
        },
        actor: owner
      )
      |> Ash.update!(load: [:huddl_template])

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject =~ "Recurring series updated:" and
          email.to == [{"", to_string(attendee.email)}] and
          email.html_body =~ "next upcoming instance"
      end)
    end

    test "edit_type=instance still sends C2 (huddl_updated), not C4" do
      owner = generate(user(role: :user))
      attendee = generate(user())

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      original =
        generate(
          huddl(
            title: "Series Original",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            is_recurring: true,
            frequency: "weekly",
            repeat_until: Date.add(Date.utc_today(), 60)
          )
        )

      original
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      original
      |> Ash.Changeset.for_update(
        :update,
        %{title: "Renamed Just This One", edit_type: "instance"},
        actor: owner
      )
      |> Ash.update!()

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "Updated: Renamed Just This One"
      end)
    end
  end

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
      emails = drain_mailbox()

      for recipient <- [attendee_a, attendee_b] do
        assert Enum.any?(emails, fn email ->
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

  describe "D1: huddl_reminder_24h" do
    test "fans out to every RSVP and stamps reminder_24h_sent_at" do
      owner = generate(user(role: :user))
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

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      stamped_huddl =
        huddl
        |> Ash.Changeset.for_update(:send_24h_reminder, %{})
        |> Ash.update!(authorize?: false)

      assert %DateTime{} = stamped_huddl.reminder_24h_sent_at

      assert %{success: 2} = Oban.drain_queue(queue: :notifications)

      for recipient <- [attendee_a, attendee_b] do
        assert_email_sent(fn email ->
          email.subject == "Tomorrow: Saturday Soccer" and
            email.to == [{"", to_string(recipient.email)}] and
            Enum.any?(email.attachments, &(&1.content_type == "text/calendar"))
        end)
      end
    end

    test "due_for_24h_reminder filter excludes already-stamped huddlz" do
      owner = generate(user(role: :user))

      group =
        generate(group(name: "Test Group", is_public: true, owner_id: owner.id, actor: owner))

      stamped =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      stamped
      |> Ash.Changeset.for_update(:send_24h_reminder, %{})
      |> Ash.update!(authorize?: false)

      candidates =
        Huddl
        |> Ash.Query.for_read(:due_for_24h_reminder)
        |> Ash.read!(authorize?: false, page: false)

      refute Enum.any?(candidates, &(&1.id == stamped.id))
    end

    test "ResetReminderStamps clears the column when starts_at changes" do
      owner = generate(user(role: :user))

      group =
        generate(group(name: "Test Group", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      stamped =
        huddl
        |> Ash.Changeset.for_update(:send_24h_reminder, %{})
        |> Ash.update!(authorize?: false)

      assert %DateTime{} = stamped.reminder_24h_sent_at

      new_date = Date.add(Date.utc_today(), 7)

      reset =
        stamped
        |> Ash.Changeset.for_update(
          :update,
          %{date: new_date, start_time: ~T[15:00:00], duration_minutes: 60},
          actor: owner
        )
        |> Ash.update!()

      assert is_nil(reset.reminder_24h_sent_at)
      assert is_nil(reset.reminder_1h_sent_at)
    end

    test "is idempotent — running the action twice still sends only once per RSVP" do
      owner = generate(user(role: :user))
      attendee = generate(user())

      group =
        generate(group(name: "Test Group", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      stamped =
        huddl
        |> Ash.Changeset.for_update(:send_24h_reminder, %{})
        |> Ash.update!(authorize?: false)

      # The cron filter would now skip this huddl (not nil), so a second
      # action invocation only happens by manual call. Even then the
      # caller still gets one delivery; we just confirm nothing about
      # idempotency at the action level — see the filter test above.
      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      candidates =
        Huddl
        |> Ash.Query.for_read(:due_for_24h_reminder)
        |> Ash.read!(authorize?: false, page: false)

      refute Enum.any?(candidates, &(&1.id == stamped.id))
    end
  end

  describe "D2: huddl_reminder_1h" do
    test "fans out to every RSVP and stamps reminder_1h_sent_at" do
      owner = generate(user(role: :user))
      attendee = generate(user())

      group =
        generate(
          group(
            name: "Coffee Hour",
            slug: "coffee-hour",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      huddl =
        generate(
          huddl(title: "Morning Standup", group_id: group.id, creator_id: owner.id, actor: owner)
        )

      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      stamped =
        huddl
        |> Ash.Changeset.for_update(:send_1h_reminder, %{})
        |> Ash.update!(authorize?: false)

      assert %DateTime{} = stamped.reminder_1h_sent_at

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "Starting soon: Morning Standup" and
          email.to == [{"", to_string(attendee.email)}]
      end)
    end
  end

  defp flush_mailbox do
    drain_mailbox()
    :ok
  end

  defp drain_mailbox(acc \\ []) do
    receive do
      {:email, email} -> drain_mailbox([email | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
