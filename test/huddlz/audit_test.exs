defmodule Huddlz.AuditTest do
  use Huddlz.DataCase, async: false
  @moduletag :audit_history

  require Ash.Query
  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries

  setup do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, actor: owner))
    huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
    %{owner: owner, group: group, huddl: huddl}
  end

  test "failed history writes roll back the huddl change", %{owner: owner, huddl: huddl} do
    # A real database failure in the version insert, after the huddl update.
    Repo.query!(
      "ALTER TABLE huddlz_versions ADD CONSTRAINT reject_audit_test CHECK (version_action_name != 'update')"
    )

    assert_raise Ash.Error.Unknown, fn ->
      Communities.update_huddl!(huddl, %{title: "Must roll back"}, actor: owner)
    end

    assert Ash.get!(Huddl, huddl.id, authorize?: false).title == huddl.title
  end

  test "deleting a huddl retains its versions and deletion", %{owner: owner, group: group} do
    huddl = generate(huddl(group_id: group.id, actor: owner, lifecycle_state: :draft))
    Ash.destroy!(huddl, actor: owner)
    versions = versions(huddl)
    assert Enum.any?(versions, &(&1.version_action_type == :create))
    assert Enum.any?(versions, &(&1.version_action_type == :destroy))
  end

  test "audit versions cannot be read or written through ordinary authorization", %{
    owner: owner,
    huddl: huddl
  } do
    admin = generate(user(role: :admin))

    for actor <- [nil, owner, admin] do
      assert {:error, _} = Ash.read(Huddl.Version, actor: actor)
      assert {:error, _} = Ash.destroy(hd(versions(huddl)), action: :expire, actor: actor)
    end
  end

  test "supported metadata preserves both impersonation identities", %{owner: owner, huddl: huddl} do
    admin = generate(user(role: :admin))
    impersonation_id = Ash.UUID.generate()

    Communities.update_huddl!(huddl, %{title: "Support edit"},
      actor: owner,
      context: %{
        paper_trail_metadata: %{impersonation_id: impersonation_id, impersonator_id: admin.id}
      }
    )

    version = Enum.find(versions(huddl), &(&1.changes["title"] == "Support edit"))
    assert version.actor_id == owner.id
    assert version.impersonator_id == admin.id
    assert version.impersonation_id == impersonation_id
  end

  defp versions(huddl) do
    Huddl.Version
    |> Ash.Query.filter(version_source_id == ^huddl.id)
    |> Ash.read!(authorize?: false)
  end

  test "atomic bulk updates preserve audit records", %{owner: owner, huddl: huddl} do
    member = generate(user())

    attendee =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Changeset.for_create(:join_waitlist, %{huddl_id: huddl.id, user_id: member.id},
        actor: member
      )
      |> Ash.create!(authorize?: false)

    result =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Query.filter(id == ^attendee.id)
      |> Ash.bulk_update(:promote_from_waitlist, %{},
        actor: owner,
        authorize?: false,
        strategy: [:atomic],
        return_errors?: true,
        context: %{paper_trail_metadata: %{automatic?: true}}
      )

    assert result.status == :success

    rows =
      Huddlz.Communities.HuddlAttendee.Version
      |> Ash.Query.filter(version_source_id == ^attendee.id)
      |> Ash.read!(authorize?: false)

    assert Enum.any?(
             rows,
             &(&1.version_action_name == :promote_from_waitlist and &1.actor_id == owner.id and
                 &1.automatic?)
           )
  end

  test "failed audit insert rolls back an atomic bulk update", %{owner: owner, huddl: huddl} do
    member = generate(user())

    attendee =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Changeset.for_create(:join_waitlist, %{huddl_id: huddl.id, user_id: member.id},
        actor: member
      )
      |> Ash.create!(authorize?: false)

    Repo.query!(
      "ALTER TABLE huddl_attendees_versions ADD CONSTRAINT reject_bulk_audit_test CHECK (version_action_name != 'promote_from_waitlist')"
    )

    result =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Query.filter(id == ^attendee.id)
      |> Ash.bulk_update(:promote_from_waitlist, %{},
        actor: owner,
        authorize?: false,
        strategy: [:atomic],
        return_errors?: true
      )

    assert result.status == :error

    assert Ash.get!(Huddlz.Communities.HuddlAttendee, attendee.id, authorize?: false).waitlisted_at
  end

  test "recurring generation records automation rather than a new action by the creator", %{
    owner: owner,
    group: group
  } do
    source =
      generate(
        huddl(
          group_id: group.id,
          actor: owner,
          date: Date.add(eastern_today(), 2),
          is_recurring: true,
          frequency: :weekly,
          repeat_until: Date.add(eastern_today(), 10)
        )
      )

    assert :ok =
             RegenerateRecurringSeries.perform(%Oban.Job{
               args: %{"huddl_id" => source.id},
               attempt: 1,
               max_attempts: 3
             })

    rows = Ash.read!(Huddl.Version, authorize?: false)
    generated = Enum.filter(rows, &(&1.automatic? == true))
    assert generated != []
    assert Enum.all?(generated, &is_nil(&1.actor_id))
  end

  test "membership history distinguishes the organizer from the affected member", %{
    owner: owner,
    group: group
  } do
    member = generate(user())
    membership = Communities.add_member!(group.id, member.id, :member, actor: owner)
    Communities.remove_member!(membership, group.id, member.id, actor: owner)

    rows =
      Huddlz.Communities.GroupMember.Version
      |> Ash.Query.filter(version_source_id == ^membership.id)
      |> Ash.read!(authorize?: false)

    assert Enum.any?(rows, fn row ->
             row.version_action_name == :remove_member and
               row.actor_id == owner.id and row.changes["user_id"] == member.id
           end)
  end

  test "nested participation preserves actor and metadata and identifies automatic promotion", %{
    owner: owner,
    group: group
  } do
    huddl = generate(huddl(group_id: group.id, actor: owner, max_attendees: 1))
    member = generate(user())
    impersonator = generate(user(role: :admin))
    id = Ash.UUID.generate()
    metadata = %{impersonation_id: id, impersonator_id: impersonator.id}
    opts = [actor: owner, context: %{paper_trail_metadata: metadata}]

    Communities.cancel_rsvp_huddl!(huddl, actor: owner)
    Communities.rsvp_huddl!(huddl, opts)
    Communities.join_waitlist_huddl!(huddl, actor: member)
    Communities.cancel_rsvp_huddl!(huddl, opts)

    rows = Ash.read!(Huddlz.Communities.HuddlAttendee.Version, authorize?: false)
    rsvp = Enum.find(rows, &(&1.version_action_name == :rsvp and &1.impersonation_id == id))
    assert rsvp
    assert rsvp.actor_id == owner.id
    assert rsvp.impersonation_id == id
    promotion = Enum.find(rows, &(&1.version_action_name == :promote_from_waitlist))
    assert promotion.automatic?
    assert promotion.actor_id == owner.id
    assert promotion.changes["user_id"] == member.id
    assert promotion.impersonation_id == id
  end

  test "account changes omit secrets and direct profile data", %{owner: owner} do
    Huddlz.Accounts.update_display_name!(owner, "Private profile value", actor: owner)
    rows = Ash.read!(Huddlz.Accounts.User.Version, authorize?: false)

    assert rows != []

    for row <- rows do
      refute Map.has_key?(row.changes, "email")
      refute Map.has_key?(row.changes, "display_name")
      refute Map.has_key?(row.changes, "hashed_password")
      refute Map.has_key?(row.changes, "home_location")
    end
  end

  test "account deletion clears actor and impersonator links", %{owner: owner, huddl: huddl} do
    admin = generate(user(role: :admin))

    Communities.update_huddl!(huddl, %{title: "Admin edit"},
      actor: admin,
      context: %{paper_trail_metadata: %{impersonator_id: admin.id}}
    )

    Repo.delete_all(from(user in Huddlz.Accounts.User, where: user.id == ^admin.id))
    row = Enum.find(versions(huddl), &(&1.changes["title"] == "Admin edit"))
    assert is_nil(row.actor_id)
    assert is_nil(row.impersonator_id)
    assert Ash.get!(Huddlz.Accounts.User, owner.id, authorize?: false)
  end

  test "retention removes expired versions and keeps recent history", %{
    huddl: huddl,
    owner: owner
  } do
    now = DateTime.utc_now()
    old = DateTime.add(now, -91, :day)
    [version | _] = versions(huddl)

    Repo.update_all(from(v in Huddl.Version, where: v.id == ^version.id),
      set: [version_inserted_at: old]
    )

    Communities.update_huddl!(huddl, %{title: "Recent edit"}, actor: owner)
    assert :ok = Huddlz.Audit.prune(now)
    refute Enum.any?(versions(huddl), &(&1.id == version.id))
    assert Enum.any?(versions(huddl), &(&1.changes["title"] == "Recent edit"))
  end
end
