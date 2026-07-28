defmodule Huddlz.Communities.GroupInvitationTest do
  use Huddlz.DataCase, async: true

  require Ash.Query

  alias Ecto.Adapters.SQL
  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember

  setup do
    owner = generate(user())
    organizer = generate(user())
    invitee = generate(user())

    group =
      generate(
        group(
          name: "Invitation Group #{System.unique_integer([:positive])}",
          owner_id: owner.id,
          actor: owner,
          is_public: false
        )
      )

    generate(
      group_member(
        group_id: group.id,
        user_id: organizer.id,
        role: :organizer,
        actor: owner
      )
    )

    %{owner: owner, organizer: organizer, invitee: invitee, group: group}
  end

  test "owner invitation stays pending until acceptance and grants membership once", context do
    %{owner: owner, invitee: invitee, group: group} = context

    assert {:ok, invitation} =
             Communities.invite_to_group(group.id, invitee.id, :member, actor: owner)

    assert invitation.status == :pending
    assert invitation.role == :member
    refute membership(group, invitee)
    refute visible_group?(group, invitee)

    assert {:ok, accepted} = Communities.accept_group_invitation(invitation, actor: invitee)
    assert accepted.status == :accepted
    assert membership(group, invitee).role == :member
    assert visible_group?(group, invitee)

    assert {:error, _reason} =
             Communities.accept_group_invitation(accepted, actor: invitee)

    assert membership_count(group, invitee) == 1
  end

  test "owner can invite an organizer", %{owner: owner, invitee: invitee, group: group} do
    invitation =
      Communities.invite_to_group!(group.id, invitee.id, :organizer, actor: owner)

    Communities.accept_group_invitation!(invitation, actor: invitee)

    assert membership(group, invitee).role == :organizer
  end

  test "accepting preserves the strongest role when membership changed after invitation",
       context do
    %{owner: owner, invitee: invitee, group: group} = context

    organizer_invitation =
      Communities.invite_to_group!(group.id, invitee.id, :organizer, actor: owner)

    Communities.add_member!(group.id, invitee.id, "member", actor: owner)
    Communities.accept_group_invitation!(organizer_invitation, actor: invitee)

    assert membership(group, invitee).role == :organizer

    another_invitee = generate(user())

    member_invitation =
      Communities.invite_to_group!(group.id, another_invitee.id, :member, actor: owner)

    Communities.add_member!(group.id, another_invitee.id, "organizer", actor: owner)
    Communities.accept_group_invitation!(member_invitation, actor: another_invitee)

    assert membership(group, another_invitee).role == :organizer
  end

  test "organizer can invite a member but cannot grant organizer access", context do
    %{organizer: organizer, invitee: invitee, group: group} = context

    assert {:ok, invitation} =
             Communities.invite_to_group(group.id, invitee.id, :member, actor: organizer)

    assert invitation.role == :member

    another_invitee = generate(user())

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.invite_to_group(
               group.id,
               another_invitee.id,
               :organizer,
               actor: organizer
             )
  end

  test "duplicate pending invitations are prevented", context do
    %{owner: owner, invitee: invitee, group: group} = context

    Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    assert {:error, error} =
             Communities.invite_to_group(group.id, invitee.id, :member, actor: owner)

    assert Exception.message(error) =~ "already has a pending invitation"
  end

  test "public groups do not accept invitations", %{owner: owner, invitee: invitee} do
    group =
      generate(
        group(
          name: "Public Invitation Group #{System.unique_integer([:positive])}",
          owner_id: owner.id,
          actor: owner,
          is_public: true
        )
      )

    assert {:error, error} =
             Communities.invite_to_group(group.id, invitee.id, :member, actor: owner)

    assert Exception.message(error) =~ "must belong to a private group"
  end

  test "declining leaves the invitee outside the group", context do
    %{owner: owner, invitee: invitee, group: group} = context
    invitation = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    assert {:ok, declined} =
             Communities.decline_group_invitation(invitation, actor: invitee)

    assert declined.status == :declined
    refute membership(group, invitee)

    assert {:error, _reason} =
             Communities.decline_group_invitation(declined, actor: invitee)
  end

  test "revoked and expired invitations cannot be accepted", context do
    %{owner: owner, invitee: invitee, group: group} = context
    stale_revoked = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)
    revoked = Communities.revoke_group_invitation!(stale_revoked, actor: owner)

    assert {:error, _reason} =
             Communities.accept_group_invitation(revoked, actor: invitee)

    assert {:error, _reason} =
             Communities.accept_group_invitation(stale_revoked, actor: invitee)

    another_invitee = generate(user())

    stale_expired =
      Communities.invite_to_group!(group.id, another_invitee.id, :member, actor: owner)

    expired =
      stale_expired
      |> expire_in_database()
      |> Communities.expire_group_invitation!(authorize?: false)

    assert {:error, _reason} =
             Communities.accept_group_invitation(expired, actor: another_invitee)

    assert {:error, _reason} =
             Communities.accept_group_invitation(stale_expired, actor: another_invitee)

    refute membership(group, invitee)
    refute membership(group, another_invitee)
  end

  test "an expired invitation is replaced by a fresh pending invitation", context do
    %{owner: owner, invitee: invitee, group: group} = context

    expired =
      group.id
      |> Communities.invite_to_group!(invitee.id, :member, actor: owner)
      |> expire_in_database()

    fresh = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    assert fresh.status == :pending
    assert fresh.id != expired.id
  end

  test "an outsider cannot read or respond to another person's invitation", context do
    %{owner: owner, invitee: invitee, group: group} = context
    outsider = generate(user())
    invitation = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.accept_group_invitation(invitation, actor: outsider)

    assert {:ok, nil} =
             Communities.get_my_group_invitation(
               invitation.id,
               actor: outsider,
               not_found_error?: false
             )
  end

  defp membership(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
  end

  defp membership_count(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.count!(authorize?: false)
  end

  defp visible_group?(group, user) do
    match?(
      {:ok, %Group{}},
      Communities.get_by_slug(group.slug, actor: user, not_found_error?: false)
    )
  end

  describe "pending_for_user" do
    test "lists only the actor's pending, current invitations, newest first, with group and inviter preloaded",
         context do
      %{owner: owner, invitee: invitee, group: group} = context

      accepted_group =
        generate(
          group(
            name: "Accepted Group #{System.unique_integer([:positive])}",
            owner_id: owner.id,
            actor: owner,
            is_public: false
          )
        )

      accepted_group.id
      |> Communities.invite_to_group!(invitee.id, :member, actor: owner)
      |> Communities.accept_group_invitation!(actor: invitee)

      revoked_group =
        generate(
          group(
            name: "Revoked Group #{System.unique_integer([:positive])}",
            owner_id: owner.id,
            actor: owner,
            is_public: false
          )
        )

      revoked_group.id
      |> Communities.invite_to_group!(invitee.id, :member, actor: owner)
      |> Communities.revoke_group_invitation!(actor: owner)

      stranger = generate(user())
      Communities.invite_to_group!(group.id, stranger.id, :member, actor: owner)

      older = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)
      Process.sleep(2)

      another_group =
        generate(
          group(
            name: "Another Group #{System.unique_integer([:positive])}",
            owner_id: owner.id,
            actor: owner,
            is_public: false
          )
        )

      newer = Communities.invite_to_group!(another_group.id, invitee.id, :organizer, actor: owner)

      assert {:ok, %{results: results}} =
               Communities.list_pending_group_invitations_for_user(
                 actor: invitee,
                 page: [limit: 100]
               )

      assert Enum.map(results, & &1.id) == [newer.id, older.id]
      assert Enum.map(results, & &1.group.name) == [another_group.name, group.name]
      assert Enum.all?(results, &(&1.inviter.id == owner.id))
    end

    test "excludes invitations that are technically expired but not yet flipped to :expired in the DB",
         context do
      %{owner: owner, invitee: invitee, group: group} = context

      group.id
      |> Communities.invite_to_group!(invitee.id, :member, actor: owner)
      |> expire_in_database()

      assert {:ok, %{results: []}} =
               Communities.list_pending_group_invitations_for_user(
                 actor: invitee,
                 page: [limit: 100]
               )
    end
  end

  defp expire_in_database(invitation) do
    expires_at = DateTime.add(DateTime.utc_now(), -1, :day)

    SQL.query!(
      Huddlz.Repo,
      "UPDATE group_invitations SET expires_at = $1 WHERE id = $2",
      [expires_at, Ecto.UUID.dump!(invitation.id)]
    )

    Communities.get_group_invitation!(invitation.id, authorize?: false)
  end
end
