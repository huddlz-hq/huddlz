defmodule Huddlz.AuditTest do
  use Huddlz.DataCase, async: false
  @moduletag :audit_history

  require Ash.Query
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupInvitation
  alias Huddlz.Communities.GroupInvitation.ConfirmedRecipientWorker
  alias Huddlz.Communities.GroupInvitation.EmailToken
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries

  test "invitation expiry is explicitly automatic", %{owner: owner} do
    group = generate(group(actor: owner, is_public: false))
    email = "audit-#{Ash.UUID.generate()}@example.com"
    invitation = Communities.invite_to_group_by_email!(group.id, email, :member, actor: owner)

    Repo.update_all(from(i in GroupInvitation, where: i.id == ^invitation.id),
      set: [expires_at: DateTime.add(DateTime.utc_now(), -60)]
    )

    invitation = Ash.get!(GroupInvitation, invitation.id, authorize?: false)
    Communities.expire_group_invitation!(invitation, authorize?: false)

    row =
      GroupInvitation.Version
      |> Ash.Query.filter(version_source_id == ^invitation.id and version_action_name == :expire)
      |> Ash.read_one!(authorize?: false)

    assert row.automatic?
    assert is_nil(row.actor_id)
  end

  test "re-inviting during impersonation preserves attribution on the previous expiry", %{
    owner: owner
  } do
    group = generate(group(actor: owner, is_public: false))
    email = "audit-#{Ash.UUID.generate()}@example.com"
    invitation = Communities.invite_to_group_by_email!(group.id, email, :member, actor: owner)
    admin = generate(user(role: :admin))
    impersonation_id = Ash.UUID.generate()

    Repo.update_all(from(i in GroupInvitation, where: i.id == ^invitation.id),
      set: [expires_at: DateTime.add(DateTime.utc_now(), -60)]
    )

    replacement =
      Communities.invite_to_group_by_email!(group.id, email, :member,
        actor: owner,
        context: %{
          paper_trail_metadata: %{impersonation_id: impersonation_id, impersonator_id: admin.id}
        }
      )

    assert replacement.id != invitation.id
    assert replacement.status == :pending

    row =
      GroupInvitation.Version
      |> Ash.Query.filter(version_source_id == ^invitation.id and version_action_name == :expire)
      |> Ash.read_one!(authorize?: false)

    assert row.automatic?
    assert row.actor_id == owner.id
    assert row.impersonation_id == impersonation_id
    assert row.impersonator_id == admin.id
  end

  test "completion is explicitly automatic", %{huddl: huddl} do
    now = DateTime.utc_now()

    Repo.update_all(from(h in Huddl, where: h.id == ^huddl.id),
      set: [starts_at: DateTime.add(now, -7200), ends_at: DateTime.add(now, -3600)]
    )

    huddl = Ash.get!(Huddl, huddl.id, authorize?: false)
    Communities.complete_huddl!(huddl, authorize?: false)
    row = Enum.find(versions(huddl), &(&1.version_action_name == :complete))
    assert row.automatic?
    assert is_nil(row.actor_id)
  end

  test "confirmed-recipient claims are automatic rather than actions by the recipient", %{
    owner: owner
  } do
    group = generate(group(actor: owner, is_public: false))
    email = "audit-#{Ash.UUID.generate()}@example.com"
    invitation = Communities.invite_to_group_by_email!(group.id, email, :member, actor: owner)
    recipient = generate(user(email: email))

    assert :ok =
             ConfirmedRecipientWorker.perform(%Oban.Job{
               args: %{"user_id" => recipient.id, "email" => email}
             })

    row = invitation_claim(invitation)
    assert row.automatic?
    assert is_nil(row.actor_id)
    assert row.changes["invitee_id"] == recipient.id
  end

  test "opening an email invitation preserves impersonation attribution", %{owner: owner} do
    group = generate(group(actor: owner, is_public: false))
    email = "audit-#{Ash.UUID.generate()}@example.com"
    invitation = Communities.invite_to_group_by_email!(group.id, email, :member, actor: owner)
    recipient = generate(user(email: email))
    admin = generate(user(role: :admin))
    id = Ash.UUID.generate()

    Communities.open_email_group_invitation!(EmailToken.sign(invitation),
      actor: recipient,
      context: %{paper_trail_metadata: %{impersonation_id: id, impersonator_id: admin.id}}
    )

    row = invitation_claim(invitation)
    assert row.actor_id == recipient.id
    assert row.impersonation_id == id
    assert row.impersonator_id == admin.id
  end

  defp invitation_claim(invitation) do
    GroupInvitation.Version
    |> Ash.Query.filter(version_source_id == ^invitation.id and version_action_name == :claim)
    |> Ash.read_one!(authorize?: false)
  end

  test "extending a series records the editor without changing its original creator", %{
    owner: owner,
    group: group
  } do
    editor = generate(user())
    Communities.add_member!(group.id, editor.id, :organizer, actor: owner)
    date = Date.add(eastern_today(), 2)

    source =
      generate(
        huddl(
          group_id: group.id,
          actor: owner,
          date: date,
          is_recurring: true,
          frequency: :weekly,
          repeat_until: Date.add(date, 7)
        )
      )

    id = Ash.UUID.generate()

    Communities.update_huddl!(
      source,
      %{edit_type: "all", frequency: :weekly, repeat_until: Date.add(date, 14)},
      actor: editor,
      context: %{paper_trail_metadata: %{impersonation_id: id}}
    )

    generated =
      Huddl.Version
      |> Ash.Query.filter(impersonation_id == ^id and version_action_type == :create)
      |> Ash.read!(authorize?: false)

    assert generated != []
    assert Enum.all?(generated, &(&1.actor_id == editor.id))
    assert Enum.all?(generated, &(&1.changes["creator_id"] == owner.id))
  end

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

  test "account deletion clears actor and impersonator links", %{
    owner: owner,
    group: group,
    huddl: huddl
  } do
    admin = generate(user(role: :admin))

    membership = Communities.add_member!(group.id, admin.id, :organizer, actor: owner)

    Communities.update_huddl!(huddl, %{title: "Admin edit"},
      actor: admin,
      context: %{paper_trail_metadata: %{impersonator_id: admin.id}}
    )

    Communities.remove_member!(membership, group.id, admin.id, actor: owner)
    Repo.delete_all(from(user in Huddlz.Accounts.User, where: user.id == ^admin.id))
    row = Enum.find(versions(huddl), &(&1.changes["title"] == "Admin edit"))
    assert is_nil(row.actor_id)
    assert is_nil(row.impersonator_id)
    assert Ash.get!(Huddlz.Accounts.User, owner.id, authorize?: false)
  end

  # An edit is troubleshooting history and goes after 90 days; the huddl's
  # creation is participation history and stays (ADR 0007).
  test "retention removes expired versions and keeps recent history", %{
    huddl: huddl,
    owner: owner
  } do
    now = DateTime.utc_now()
    old = DateTime.add(now, -91, :day)
    Communities.update_huddl!(huddl, %{title: "Old edit"}, actor: owner)
    version = Enum.find(versions(huddl), &(&1.changes["title"] == "Old edit"))

    Repo.update_all(from(v in Huddl.Version, where: v.id == ^version.id),
      set: [version_inserted_at: old]
    )

    Communities.update_huddl!(huddl, %{title: "Recent edit"}, actor: owner)
    assert :ok = Huddlz.Audit.prune(now)
    refute Enum.any?(versions(huddl), &(&1.id == version.id))
    assert Enum.any?(versions(huddl), &(&1.changes["title"] == "Recent edit"))
    assert Enum.any?(versions(huddl), &(&1.version_action_name == :create))
  end
end
