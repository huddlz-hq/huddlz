defmodule Huddlz.AuditNestedActionsTest do
  use Huddlz.DataCase, async: false
  @moduletag :audit_history

  require Ash.Query
  alias Huddlz.Accounts
  alias Huddlz.Accounts.ProfilePicture
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupImage
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Communities.HuddlCoverImage

  setup do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, actor: owner))
    admin = generate(user(role: :admin))
    impersonation_id = Ash.UUID.generate()

    opts = [
      actor: owner,
      context: %{
        paper_trail_metadata: %{
          impersonation_id: impersonation_id,
          impersonator_id: admin.id
        }
      }
    ]

    %{owner: owner, group: group, admin: admin, impersonation_id: impersonation_id, opts: opts}
  end

  test "capacity-driven promotion retains attribution and identifies automation", ctx do
    huddl = generate(huddl(group_id: ctx.group.id, actor: ctx.owner, max_attendees: 1))
    member = generate(user())
    Communities.join_waitlist_huddl!(huddl, actor: member)

    Communities.update_huddl!(huddl, %{max_attendees: 2}, ctx.opts)

    row =
      HuddlAttendee.Version
      |> Ash.Query.filter(version_action_name == :promote_from_waitlist)
      |> Ash.read_one!(authorize?: false)

    assert row
    assert row.changes["user_id"] == member.id

    assert {row.actor_id, row.impersonator_id, row.impersonation_id, row.automatic?} ==
             {ctx.owner.id, ctx.admin.id, ctx.impersonation_id, true}
  end

  test "generic membership removal preserves supplied impersonation metadata", ctx do
    member = generate(user())
    membership = Communities.add_member!(ctx.group.id, member.id, :member, actor: ctx.owner)

    GroupMember
    |> Ash.ActionInput.for_action(
      :remove_member_by_ids,
      %{group_id: ctx.group.id, user_id: member.id},
      ctx.opts
    )
    |> Ash.run_action!()

    row =
      GroupMember.Version
      |> Ash.Query.filter(
        version_source_id == ^membership.id and version_action_name == :remove_member
      )
      |> Ash.read_one!(authorize?: false)

    assert row.actor_id == ctx.owner.id

    assert {row.impersonator_id, row.impersonation_id} ==
             {ctx.admin.id, ctx.impersonation_id}
  end

  test "notification delivery does not create resource audit snapshots", ctx do
    huddl = generate(huddl(group_id: ctx.group.id, actor: ctx.owner))

    for action <- [:send_24h_reminder, :send_1h_reminder] do
      updated = Ash.update!(huddl, %{}, action: action, authorize?: false)

      assert Map.fetch!(
               updated,
               if(action == :send_24h_reminder,
                 do: :reminder_24h_sent_at,
                 else: :reminder_1h_sent_at
               )
             )
    end

    rows =
      Huddl.Version
      |> Ash.Query.filter(
        version_source_id == ^huddl.id and
          version_action_name in [:send_24h_reminder, :send_1h_reminder]
      )
      |> Ash.read!(authorize?: false)

    assert rows == []
  end

  test "background profile cleanup identifies automation", ctx do
    picture = Accounts.create_profile_picture!(picture_attrs(ctx.owner), actor: ctx.owner)
    picture = Accounts.soft_delete_profile_picture!(picture, actor: ctx.owner)
    perform_cleanup(picture, :cleanup_storage)

    row =
      ProfilePicture.Version
      |> Ash.Query.filter(
        version_source_id == ^picture.id and version_action_name == :hard_delete
      )
      |> Ash.read_one!(authorize?: false)

    assert row
    assert row.automatic? == true
  end

  test "profile replacement retirement retains impersonation attribution", ctx do
    picture = Accounts.create_profile_picture!(picture_attrs(ctx.owner), actor: ctx.owner)
    Accounts.replace_profile_picture!(picture_attrs(ctx.owner), ctx.opts)

    row =
      ProfilePicture.Version
      |> Ash.Query.filter(
        version_source_id == ^picture.id and version_action_name == :soft_delete
      )
      |> Ash.read_one!(authorize?: false)

    assert row.actor_id == ctx.owner.id
    assert row.automatic?
    assert {row.impersonator_id, row.impersonation_id} == {ctx.admin.id, ctx.impersonation_id}
  end

  test "pending cover assignment preserves the initiating identities", ctx do
    image =
      Communities.create_pending_huddl_cover_image!(ctx.group.id, image_attrs(), actor: ctx.owner)

    huddl =
      Huddl
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_argument(:pending_image_id, image.id)
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "With pending cover",
          description: "Test",
          group_id: ctx.group.id,
          date: Date.add(Date.utc_today(), 2),
          start_time: ~T[14:00:00],
          duration_minutes: 60,
          event_type: :virtual,
          virtual_link: "https://example.com/meet"
        },
        ctx.opts
      )
      |> Ash.create!()

    row = version(HuddlCoverImage.Version, image, :assign_to_huddl)
    assert row.changes["huddl_id"] == huddl.id
    assert_attribution(row, ctx)
  end

  test "group and cover cleanup workers mark all cleanup actions automatic", ctx do
    for {resource, create} <- [
          {GroupImage,
           fn -> Communities.create_pending_group_image!(image_attrs(), actor: ctx.owner) end},
          {HuddlCoverImage,
           fn ->
             Communities.create_pending_huddl_cover_image!(ctx.group.id, image_attrs(),
               actor: ctx.owner
             )
           end}
        ],
        {trigger, action} <- [
          cleanup_storage: :hard_delete,
          cleanup_orphaned_images: :cleanup_orphaned
        ] do
      image = create.()

      Repo.update_all(from(i in resource, where: i.id == ^image.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -48, :hour)]
      )

      perform_cleanup(image, trigger)
      row = version(Module.concat(resource, Version), image, action)
      assert row.automatic?
      assert is_nil(row.actor_id)
      assert [] == resource |> Ash.Query.filter(id == ^image.id) |> Ash.read!(authorize?: false)
    end
  end

  test "synchronous cover deletion preserves deliberate attribution", ctx do
    huddl = generate(huddl(group_id: ctx.group.id, actor: ctx.owner))

    image =
      Communities.create_huddl_cover_image!(Map.put(image_attrs(), :huddl_id, huddl.id),
        actor: ctx.owner
      )

    Ash.destroy!(image, Keyword.merge(ctx.opts, action: :hard_delete))
    row = version(HuddlCoverImage.Version, image, :hard_delete)
    assert_attribution(row, ctx)
    refute row.automatic?
  end

  test "membership removal still denies a person without permission", ctx do
    member = generate(user())
    outsider = generate(user())
    membership = Communities.add_member!(ctx.group.id, member.id, :member, actor: ctx.owner)

    result =
      GroupMember
      |> Ash.ActionInput.for_action(
        :remove_member_by_ids,
        %{group_id: ctx.group.id, user_id: member.id},
        Keyword.put(ctx.opts, :actor, outsider)
      )
      |> Ash.run_action()

    assert {:error, %Ash.Error.Forbidden{}} = result
    assert Ash.get!(GroupMember, membership.id, authorize?: false)
  end

  defp perform_cleanup(image, trigger) do
    job = image |> AshOban.build_trigger(trigger) |> Ecto.Changeset.apply_changes()
    worker = AshOban.Info.oban_trigger(image.__struct__, trigger).worker_module_name
    assert :ok = Oban.Testing.perform_job(worker, job.args, repo: Repo)
  end

  defp version(resource, record, action) do
    resource
    |> Ash.Query.filter(version_source_id == ^record.id and version_action_name == ^action)
    |> Ash.read_one!(authorize?: false)
  end

  defp assert_attribution(row, ctx) do
    assert {row.actor_id, row.impersonator_id, row.impersonation_id} ==
             {ctx.owner.id, ctx.admin.id, ctx.impersonation_id}
  end

  defp image_attrs do
    %{
      filename: "audit.jpg",
      content_type: "image/jpeg",
      size_bytes: 1000,
      storage_path: "/uploads/pending/audit-#{Ash.UUID.generate()}.jpg"
    }
  end

  defp picture_attrs(owner) do
    %{
      filename: "review.jpg",
      content_type: "image/jpeg",
      size_bytes: 1000,
      storage_path: "/uploads/profile_pictures/#{owner.id}/review-#{Ash.UUID.generate()}.jpg",
      user_id: owner.id
    }
  end
end
