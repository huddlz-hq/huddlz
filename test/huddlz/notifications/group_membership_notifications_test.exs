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

  alias Huddlz.Communities.GroupMember
  alias Huddlz.Notifications.DeliverWorker

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
end
