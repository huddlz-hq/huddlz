defmodule HuddlzWeb.OrganizeLiveMembersTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember

  setup do
    owner = generate(user(role: :user, display_name: "Owner Olivia"))
    organizer = generate(user(role: :user, display_name: "Organizer Oscar"))
    member = generate(user(role: :user, display_name: "Member Mia"))

    {group, [organizer_membership, member_membership]} =
      generate_group_with_members(
        owner: owner,
        group: [name: "Community Council", slug: "community-council"],
        members: [
          %{user: organizer, role: :organizer},
          %{user: member, role: :member}
        ]
      )

    %{
      group: group,
      owner: owner,
      organizer: organizer,
      member: member,
      organizer_membership: organizer_membership,
      member_membership: member_membership
    }
  end

  test "owner sees policy-backed controls for each manageable role", %{
    conn: conn,
    owner: owner,
    group: group,
    organizer_membership: organizer_membership,
    member_membership: member_membership
  } do
    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/members")
    |> assert_has("#promote-member-#{member_membership.id}", text: "Promote")
    |> assert_has("#remove-member-#{member_membership.id}", text: "Remove")
    |> assert_has("#demote-member-#{organizer_membership.id}", text: "Demote")
    |> assert_has("#remove-member-#{organizer_membership.id}", text: "Remove")
    |> assert_has("#transfer-owner-#{organizer_membership.id}", text: "Transfer ownership")
    |> refute_has("[id^='remove-member-']", text: "Owner Olivia")
  end

  test "owner can promote a member and the roster updates immediately", %{
    conn: conn,
    owner: owner,
    group: group,
    member_membership: member_membership
  } do
    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/members")
    |> click_button("Promote")
    |> assert_has("#member-action-dialog-title", text: "Promote Member Mia?")
    |> within("#member-action-dialog", fn session ->
      click_button(session, "Promote to organizer")
    end)
    |> assert_has("div[role='alert']", text: "Member Mia is now an organizer.")
    |> assert_has("#demote-member-#{member_membership.id}", text: "Demote")

    assert Ash.get!(GroupMember, member_membership.id, authorize?: false).role == :organizer
  end

  test "organizer can remove a regular member but cannot manage privileged roles", %{
    conn: conn,
    organizer: organizer,
    group: group,
    organizer_membership: organizer_membership,
    member_membership: member_membership
  } do
    conn
    |> login(organizer)
    |> visit(~p"/organize/#{group.slug}/members")
    |> assert_has("#remove-member-#{member_membership.id}", text: "Remove")
    |> refute_has("#promote-member-#{member_membership.id}")
    |> refute_has("#demote-member-#{organizer_membership.id}")
    |> refute_has("#remove-member-#{organizer_membership.id}")
    |> refute_has("[id^='transfer-owner-']")
    |> click_button("Remove")
    |> assert_has("#member-action-dialog-title", text: "Remove Member Mia?")
    |> within("#member-action-dialog", fn session ->
      click_button(session, "Remove from group")
    end)
    |> assert_has("div[role='alert']", text: "Member Mia was removed from the group.")
    |> refute_has(".role-section .row-title", text: "Member Mia")

    assert Ash.get(GroupMember, member_membership.id,
             authorize?: false,
             not_found_error?: false
           ) == {:ok, nil}
  end

  test "organizer cannot confirm a stale removal after the member is promoted", %{
    conn: conn,
    owner: owner,
    organizer: organizer,
    group: group,
    member_membership: member_membership
  } do
    {:ok, view, _html} =
      conn
      |> login(organizer)
      |> live(~p"/organize/#{group.slug}/members")

    view
    |> element("#remove-member-#{member_membership.id}")
    |> render_click()

    assert {:ok, _membership} =
             Communities.change_member_role(member_membership, :organizer, actor: owner)

    assert has_element?(view, "#member-action-dialog")

    view
    |> element("#member-action-form")
    |> render_submit()

    assert Ash.get!(GroupMember, member_membership.id, authorize?: false).role == :organizer
  end

  test "ownership transfer requires typed confirmation and swaps the roles", %{
    conn: conn,
    owner: owner,
    organizer: organizer,
    group: group,
    organizer_membership: organizer_membership
  } do
    session =
      conn
      |> login(owner)
      |> visit(~p"/organize/#{group.slug}/members")
      |> click_button(
        "#transfer-owner-#{organizer_membership.id}",
        "Transfer ownership"
      )
      |> assert_has("#member-action-dialog-title", text: "Transfer ownership to Organizer Oscar?")
      |> assert_has("#member-action-confirm[disabled]", text: "Transfer ownership")

    session =
      session
      |> fill_in("Type Community Council to confirm", with: "Community Council")
      |> assert_has("#member-action-confirm:not([disabled])", text: "Transfer ownership")

    session
    |> within("#member-action-dialog", fn session ->
      click_button(session, "Transfer ownership")
    end)
    |> assert_has("div[role='alert']", text: "Ownership transferred to Organizer Oscar.")

    reloaded_group = Ash.get!(Group, group.id, authorize?: false)
    assert reloaded_group.owner_id == organizer.id

    memberships =
      Communities.get_by_group!(group.id, actor: organizer)
      |> Map.new(&{&1.user_id, &1.role})

    assert memberships[owner.id] == :organizer
    assert memberships[organizer.id] == :owner
  end

  test "an already-mounted organizer workspace redirects after role loss", %{
    conn: conn,
    owner: owner,
    organizer: organizer,
    group: group,
    organizer_membership: organizer_membership
  } do
    {:ok, view, _html} =
      conn
      |> login(organizer)
      |> live(~p"/organize/#{group.slug}/members")

    assert {:ok, _} =
             Communities.change_member_role(organizer_membership, :member, actor: owner)

    assert_redirect(view, ~p"/organize")
  end

  test "an already-mounted group page updates the affected member's access", %{
    conn: conn,
    owner: owner,
    member: member,
    group: group,
    member_membership: member_membership
  } do
    {:ok, view, _html} =
      conn
      |> login(member)
      |> live(~p"/groups/#{group.slug}")

    create_huddl_selector = "a[href='/groups/#{group.slug}/huddlz/new']"
    refute has_element?(view, create_huddl_selector)

    assert {:ok, promoted_membership} =
             Communities.change_member_role(member_membership, :organizer, actor: owner)

    assert has_element?(view, create_huddl_selector)

    assert :ok =
             Communities.remove_member(
               promoted_membership,
               group.id,
               member.id,
               actor: owner
             )

    refute has_element?(view, create_huddl_selector)

    assert has_element?(
             view,
             ".huddl-side-section .muted",
             "Only members can see who's in this group."
           )
  end
end
