defmodule HuddlzWeb.GroupRoleLiveTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Communities

  setup do
    owner = generate(user(role: :user, display_name: "Group Owner"))
    organizer = generate(user(role: :user, display_name: "Group Organizer"))
    member = generate(user(role: :user, display_name: "Group Member"))

    group =
      generate(
        group(
          name: "Role Vocabulary Group",
          is_public: true,
          owner_id: owner.id,
          actor: owner
        )
      )

    organizer_membership =
      generate(
        group_member(
          group_id: group.id,
          user_id: organizer.id,
          role: :organizer,
          actor: owner
        )
      )

    member_membership =
      generate(
        group_member(
          group_id: group.id,
          user_id: member.id,
          role: :member,
          actor: owner
        )
      )

    %{
      group: group,
      owner: owner,
      organizer: organizer,
      organizer_membership: organizer_membership,
      member: member,
      member_membership: member_membership
    }
  end

  describe "group page role" do
    test "shows the actor's actual owner, organizer, or member role", %{
      conn: conn,
      group: group,
      owner: owner,
      organizer: organizer,
      member: member
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("#current-group-role", text: "Owner")

      conn
      |> login(organizer)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("#current-group-role", text: "Organizer")

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("#current-group-role", text: "Member")
    end

    test "does not imply a membership role for non-members or admins", %{
      conn: conn,
      group: group
    } do
      non_member = generate(user(role: :user))
      admin = generate(user(role: :admin))

      conn
      |> login(non_member)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("#current-group-role")

      conn
      |> login(admin)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("#current-group-role")
    end
  end

  describe "My groups and organizer navigation roles" do
    test "cards and organizer navigation use the same role vocabulary", %{
      conn: conn,
      group: group,
      owner: owner,
      organizer: organizer,
      member: member
    } do
      conn
      |> login(owner)
      |> visit(~p"/my-groups")
      |> assert_has(~s(.card[href="/groups/#{group.slug}"] .card-tag), text: "Owner")
      |> assert_has(~s(.sb-org-row[href="/organize/#{group.slug}"] .group-role), text: "Owner")

      conn
      |> login(organizer)
      |> visit(~p"/my-groups")
      |> assert_has(~s(.card[href="/groups/#{group.slug}"] .card-tag), text: "Organizer")
      |> assert_has(
        ~s(.sb-org-row[href="/organize/#{group.slug}"] .group-role),
        text: "Organizer"
      )

      conn
      |> login(member)
      |> visit(~p"/my-groups")
      |> assert_has(~s(.card[href="/groups/#{group.slug}"] .card-tag), text: "Member")
      |> refute_has(~s(.sb-org-row[href="/organize/#{group.slug}"]))
    end

    test "organizer picker names owner and organizer roles", %{
      conn: conn,
      group: group,
      owner: owner,
      organizer: organizer
    } do
      conn
      |> login(owner)
      |> visit(~p"/organize")
      |> assert_has(~s(.row[href="/organize/#{group.slug}"] .group-role), text: "Owner")

      conn
      |> login(organizer)
      |> visit(~p"/organize")
      |> assert_has(~s(.row[href="/organize/#{group.slug}"] .group-role), text: "Organizer")
    end
  end

  describe "connected role updates" do
    test "promotion and demotion update mounted group and My groups views", %{
      conn: conn,
      group: group,
      owner: owner,
      member: member,
      member_membership: membership
    } do
      group_page =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}")
        |> assert_has("#current-group-role", text: "Member")

      my_groups =
        conn
        |> login(member)
        |> visit(~p"/my-groups")
        |> assert_has(~s(.card[href="/groups/#{group.slug}"] .card-tag), text: "Member")

      Communities.change_member_role!(membership, :organizer, actor: owner)

      group_page
      |> assert_has("#current-group-role", text: "Organizer")

      my_groups
      |> assert_has(~s(.card[href="/groups/#{group.slug}"] .card-tag), text: "Organizer")
      |> assert_has(
        ~s(.sb-org-row[href="/organize/#{group.slug}"] .group-role),
        text: "Organizer"
      )

      promoted_membership =
        Communities.get_membership_in_group!(group.id, actor: member)

      Communities.change_member_role!(promoted_membership, :member, actor: owner)

      group_page
      |> assert_has("#current-group-role", text: "Member")

      my_groups
      |> assert_has(~s(.card[href="/groups/#{group.slug}"] .card-tag), text: "Member")
      |> refute_has(~s(.sb-org-row[href="/organize/#{group.slug}"]))
    end

    test "ownership transfer updates both people's mounted role labels", %{
      conn: conn,
      group: group,
      owner: owner,
      organizer: organizer
    } do
      owner_page =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}")
        |> assert_has("#current-group-role", text: "Owner")

      organizer_page =
        conn
        |> login(organizer)
        |> visit(~p"/groups/#{group.slug}")
        |> assert_has("#current-group-role", text: "Organizer")

      Communities.transfer_group_ownership!(group, organizer.id, actor: owner)

      owner_page
      |> assert_has("#current-group-role", text: "Organizer")

      organizer_page
      |> assert_has("#current-group-role", text: "Owner")
    end

    test "removal clears the role and rejoining restores Member", %{
      conn: conn,
      group: group,
      owner: owner,
      member: member,
      member_membership: membership
    } do
      group_page =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}")
        |> assert_has("#current-group-role", text: "Member")

      Communities.remove_member!(membership, group.id, member.id, actor: owner)

      group_page
      |> refute_has("#current-group-role")
      |> assert_has("button", text: "Join Group")
      |> click_button("Join Group")
      |> assert_has("#current-group-role", text: "Member")
    end
  end
end
