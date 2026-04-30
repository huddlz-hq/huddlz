defmodule Huddlz.Notifications.GroupMembershipNotificationsTest do
  @moduledoc """
  Integration coverage for the B-series group-membership notifications
  (see `docs/notifications.md`). Exercises each Ash action end-to-end
  through the Oban worker and asserts the resulting Swoosh email.
  """

  use Huddlz.DataCase, async: false
  use Oban.Testing, repo: Huddlz.Repo

  import Swoosh.TestAssertions
  require Ash.Query

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Notifications.DeliverWorker

  describe "B1: group_member_joined" do
    test "emails the owner and every organizer when a user joins a public group" do
      owner = generate(user(role: :user, display_name: "Group Owner"))
      organizer_a = generate(user(display_name: "Org A"))
      organizer_b = generate(user(display_name: "Org B"))
      joiner = generate(user(display_name: "New Joiner"))

      group =
        generate(
          group(
            name: "Public Joinable Group",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      generate(
        group_member(
          group_id: group.id,
          user_id: organizer_a.id,
          role: :organizer,
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: group.id,
          user_id: organizer_b.id,
          role: :organizer,
          actor: owner
        )
      )

      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(:join_group, %{group_id: group.id}, actor: joiner)
        |> Ash.create(actor: joiner)

      assert %{success: 3} = Oban.drain_queue(queue: :notifications)

      for recipient_email <- [owner.email, organizer_a.email, organizer_b.email] do
        assert_email_sent(fn email ->
          email.subject == "New Joiner joined Public Joinable Group" and
            email.to == [{"", to_string(recipient_email)}] and
            email.html_body =~ "/unsubscribe/"
        end)
      end
    end

    test "skips the joiner themselves even if they are also an organizer of another role" do
      # If the joiner already had a privileged role somehow (shouldn't happen
      # via :join_group but worth guarding), they should never be a recipient.
      owner = generate(user(role: :user))

      group =
        generate(
          group(name: "Solo Owner Group", is_public: true, owner_id: owner.id, actor: owner)
        )

      joiner = generate(user())

      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(:join_group, %{group_id: group.id}, actor: joiner)
        |> Ash.create(actor: joiner)

      # success == 1 already implies the joiner is not enqueued; drain
      # plus the targeted assert below pins the recipient.
      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.to == [{"", to_string(owner.email)}]
      end)
    end
  end

  describe "B2: group_member_added" do
    test "emails the added user when added to a private group" do
      owner = generate(user(role: :user))
      added = generate(user(display_name: "Added Pat"))

      group =
        generate(
          group(
            name: "Inner Circle",
            is_public: false,
            owner_id: owner.id,
            actor: owner
          )
        )

      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: added.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "You're now a member of Inner Circle" and
          email.to == [{"", to_string(added.email)}] and
          email.html_body =~ "/unsubscribe/"
      end)
    end

    test "does not email when adding to a public group" do
      owner = generate(user(role: :user))
      added = generate(user())

      group =
        generate(
          group(
            name: "Open Public",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: added.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      refute_enqueued(worker: DeliverWorker)
    end

    test "does not email the owner when the create_group flow self-adds them" do
      # Group.:create_group fires AddOwnerAsMember internally, which calls
      # :add_member with role: "owner". That add_member must not email the
      # owner about being added to their own group.
      owner = generate(user(role: :user))
      _group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      refute_enqueued(worker: DeliverWorker)
    end
  end

  describe "B4: group_role_changed" do
    test "emails the member when an owner changes their role" do
      owner = generate(user(role: :user))
      member = generate(user(display_name: "Promoted Pat"))
      group = generate(group(name: "Promo Group", owner_id: owner.id, actor: owner))

      {:ok, membership} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      # Drain any prior add_member-triggered jobs (none for public groups,
      # but keep the queue clean) and flush any leftover test mailbox
      # messages from prior drains.
      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      {:ok, _} =
        membership
        |> Ash.Changeset.for_update(:change_role, %{role: :organizer})
        |> Ash.update(actor: owner)

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "Your role in Promo Group changed" and
          email.to == [{"", to_string(member.email)}] and
          email.html_body =~ "<strong>member</strong>" and
          email.html_body =~ "<strong>organizer</strong>" and
          email.html_body =~ "/unsubscribe/"
      end)
    end

    test "does not email when the role change is a no-op" do
      owner = generate(user(role: :user))
      member = generate(user())
      group = generate(group(owner_id: owner.id, actor: owner))

      {:ok, membership} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      Oban.drain_queue(queue: :notifications)

      {:ok, _} =
        membership
        |> Ash.Changeset.for_update(:change_role, %{role: :member})
        |> Ash.update(actor: owner)

      refute_enqueued(worker: DeliverWorker)
    end
  end

  describe "B6: group_archived" do
    test "emails every non-actor member when the group is destroyed" do
      owner = generate(user(role: :user))
      member_a = generate(user(display_name: "Alice"))
      member_b = generate(user(display_name: "Bob"))
      group = generate(group(name: "Vanishing Group", owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: member_a.id, role: :member, actor: owner)
      )

      generate(
        group_member(group_id: group.id, user_id: member_b.id, role: :member, actor: owner)
      )

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      :ok =
        group
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy!(actor: owner)

      assert %{success: 2} = Oban.drain_queue(queue: :notifications)

      for member <- [member_a, member_b] do
        assert_email_sent(fn email ->
          email.subject == "Vanishing Group has been deleted" and
            email.to == [{"", to_string(member.email)}]
        end)
      end
    end

    test "does not email the actor (the owner deleting their own group)" do
      owner = generate(user(role: :user))
      member = generate(user())
      group = generate(group(name: "Solo Vanish", owner_id: owner.id, actor: owner))

      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      :ok =
        group
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy!(actor: owner)

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.to == [{"", to_string(member.email)}]
      end)
    end
  end

  describe "B7: group_ownership_transferred" do
    test "emails both the previous and new owner" do
      previous_owner = generate(user(role: :user, display_name: "Old Owner"))
      new_owner = generate(user(display_name: "New Owner"))
      group = generate(group(name: "Council", owner_id: previous_owner.id, actor: previous_owner))

      Oban.drain_queue(queue: :notifications)
      flush_mailbox()

      {:ok, _} =
        group
        |> Ash.Changeset.for_update(:transfer_ownership, %{new_owner_id: new_owner.id})
        |> Ash.update(actor: previous_owner)

      assert %{success: 2} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "You transferred Council to a new owner" and
          email.to == [{"", to_string(previous_owner.email)}] and
          email.html_body =~ "New Owner"
      end)

      assert_email_sent(fn email ->
        email.subject == "You're the new owner of Council" and
          email.to == [{"", to_string(new_owner.email)}] and
          email.html_body =~ "Old Owner"
      end)

      reloaded = Ash.get!(Group, group.id, authorize?: false)
      assert reloaded.owner_id == new_owner.id
    end
  end

  describe "B3: group_member_removed" do
    test "emails the removed user when an owner removes them" do
      owner = generate(user(role: :user))
      group = generate(group(name: "Synthwave Crew", owner_id: owner.id, actor: owner))
      member = generate(user(display_name: "Removed Member"))

      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      membership =
        GroupMember
        |> Ash.Query.filter(group_id: group.id, user_id: member.id)
        |> Ash.read_one!(authorize?: false)

      :ok =
        membership
        |> Ash.Changeset.for_destroy(:remove_member, %{
          group_id: group.id,
          user_id: member.id
        })
        |> Ash.destroy!(actor: owner)

      assert %{success: 1} = Oban.drain_queue(queue: :notifications)

      assert_email_sent(fn email ->
        email.subject == "You were removed from Synthwave Crew" and
          email.to == [{"", to_string(member.email)}] and
          email.html_body =~ "Synthwave Crew"
      end)
    end

    test ":leave_group does not fire B3 (self-leave is B5: no email)" do
      owner = generate(user(role: :user))
      group = generate(group(name: "Self Leave", owner_id: owner.id, actor: owner))
      member = generate(user())

      {:ok, membership} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      :ok =
        membership
        |> Ash.Changeset.for_destroy(:leave_group)
        |> Ash.destroy!(actor: member)

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
