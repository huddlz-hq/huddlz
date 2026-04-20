defmodule HuddlzWeb.GroupLivePermissionsTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  describe "Group member list visibility and permissions" do
    setup do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      verified_member = generate(user(role: :user))
      regular_member = generate(user(role: :user))
      verified_non_member = generate(user(role: :user))
      regular_non_member = generate(user(role: :user))

      members = [
        %{user: organizer, role: :organizer},
        %{user: verified_member, role: :member},
        %{user: regular_member, role: :member}
      ]

      {public_group, _} =
        generate_group_with_members(
          owner: owner,
          group: [is_public: true, name: "Public Group"],
          members: members
        )

      {private_group, _} =
        generate_group_with_members(
          owner: owner,
          group: [is_public: false, name: "Private Group"],
          members: members
        )

      %{
        owner: owner,
        organizer: organizer,
        verified_member: verified_member,
        regular_member: regular_member,
        verified_non_member: verified_non_member,
        regular_non_member: regular_non_member,
        public_group: public_group,
        private_group: private_group
      }
    end

    test "owner can see full member list in public group", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: owner.display_name)
    end

    test "organizer can see full member list in public group", %{
      conn: conn,
      organizer: organizer,
      public_group: group
    } do
      conn
      |> login(organizer)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: organizer.display_name)
    end

    test "verified member can see full member list in public group", %{
      conn: conn,
      verified_member: member,
      public_group: group
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: member.display_name)
    end

    test "regular member can see member list in public group", %{
      conn: conn,
      regular_member: member,
      public_group: group
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: member.display_name)
    end

    test "verified non-member cannot see member list in public group", %{
      conn: conn,
      verified_non_member: user,
      public_group: group
    } do
      conn
      |> login(user)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: "Only members can see the member list.")
    end

    test "regular non-member cannot see member list in public group", %{
      conn: conn,
      regular_non_member: user,
      public_group: group
    } do
      conn
      |> login(user)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: "Only members can see the member list.")
    end

    test "owner can see full member list in private group", %{
      conn: conn,
      owner: owner,
      private_group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: owner.display_name)
    end

    test "organizer can see full member list in private group", %{
      conn: conn,
      organizer: organizer,
      private_group: group
    } do
      conn
      |> login(organizer)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: organizer.display_name)
    end

    test "verified member can see full member list in private group", %{
      conn: conn,
      verified_member: member,
      private_group: group
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: member.display_name)
    end

    test "regular member can see member list in private group", %{
      conn: conn,
      regular_member: member,
      private_group: group
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: member.display_name)
    end

    test "verified non-member cannot access private group", %{
      conn: conn,
      verified_non_member: user,
      private_group: group
    } do
      # Verified non-members should not be able to see private groups
      conn
      |> login(user)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h1", text: "Groups")
    end

    test "regular non-member cannot access private group", %{
      conn: conn,
      regular_non_member: user,
      private_group: group
    } do
      # Regular non-members should not be able to see private groups
      conn
      |> login(user)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h1", text: "Groups")
    end

    test "anonymous user cannot see member list in public group", %{
      conn: conn,
      public_group: group
    } do
      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h3", text: "Members")
      |> assert_has("p", text: "Please sign in to see the member list.")
    end

    test "anonymous user cannot access private group", %{conn: conn, private_group: group} do
      # Anonymous users should see not found for private groups
      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h1", text: "Groups")
    end
  end
end
