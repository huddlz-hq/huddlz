defmodule HuddlzWeb.OrganizeLiveMembersTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember

  @moduletag :organize_members

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
    |> refute_has("#ownership-danger-zone")
    |> refute_has("#open-transfer-ownership")
    |> refute_has("[id^='transfer-owner-']")
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

  test "owner can demote an organizer after confirmation", %{
    conn: conn,
    owner: owner,
    group: group,
    organizer_membership: organizer_membership
  } do
    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/members")
    |> click_button("#demote-member-#{organizer_membership.id}", "Demote")
    |> assert_has("#member-action-dialog-title", text: "Demote Organizer Oscar?")
    |> within("#member-action-dialog", fn session ->
      click_button(session, "Demote to member")
    end)
    |> assert_has("#promote-member-#{organizer_membership.id}", text: "Promote")
  end

  test "owner can remove a regular member after confirmation", %{
    conn: conn,
    owner: owner,
    group: group,
    member_membership: member_membership
  } do
    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/members")
    |> click_button("#remove-member-#{member_membership.id}", "Remove")
    |> assert_has("#member-action-dialog-title", text: "Remove Member Mia?")
    |> within("#member-action-dialog", fn session ->
      click_button(session, "Remove from group")
    end)
    |> refute_has("#remove-member-#{member_membership.id}")
  end

  test "owner can remove an organizer after confirmation", %{
    conn: conn,
    owner: owner,
    group: group,
    organizer_membership: organizer_membership
  } do
    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/members")
    |> click_button("#remove-member-#{organizer_membership.id}", "Remove")
    |> assert_has("#member-action-dialog-title", text: "Remove Organizer Oscar?")
    |> within("#member-action-dialog", fn session ->
      click_button(session, "Remove from group")
    end)
    |> refute_has("#remove-member-#{organizer_membership.id}")
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
    |> refute_has("#ownership-danger-zone")
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

    refute has_element?(view, "#member-action-dialog")
    render_submit(view, "confirm_member_action", %{})

    assert Ash.get!(GroupMember, member_membership.id, authorize?: false).role == :organizer
  end

  test "ownership transfer requires typed confirmation and swaps the roles", %{
    conn: conn,
    owner: owner,
    organizer: organizer,
    group: group
  } do
    session =
      conn
      |> login(owner)
      |> visit(~p"/organize/#{group.slug}/settings")
      |> select("New owner", option: "Organizer Oscar")
      |> click_button("#open-transfer-ownership", "Transfer group ownership")
      |> assert_has("#member-action-dialog-title", text: "Transfer ownership to Organizer Oscar?")
      |> assert_has("#member-action-dialog",
        text: "cannot reverse this transfer without the new owner’s cooperation"
      )
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
    |> assert_path(~p"/organize/#{group.slug}")
    |> refute_has("a[href='/organize/#{group.slug}/settings']")
    |> click_link("Members")
    |> assert_has("#member-member-rows")
    |> refute_has("#ownership-danger-zone")

    reloaded_group = Ash.get!(Group, group.id, authorize?: false)
    assert reloaded_group.owner_id == organizer.id

    memberships =
      Communities.get_by_group!(group.id, actor: organizer)
      |> Map.new(&{&1.user_id, &1.role})

    assert memberships[owner.id] == :organizer
    assert memberships[organizer.id] == :owner
  end

  test "organizers cannot see settings or open them directly", %{
    conn: conn,
    organizer: organizer,
    group: group
  } do
    conn = login(conn, organizer)
    {:ok, view, _} = live(conn, ~p"/organize/#{group.slug}/members")
    refute has_element?(view, "a[href='/organize/#{group.slug}/settings']")

    assert {:error, {:live_redirect, %{to: path}}} =
             live(conn, ~p"/organize/#{group.slug}/settings")

    assert path == ~p"/organize/#{group.slug}"
  end

  test "regular members cannot open settings directly", %{
    conn: conn,
    member: member,
    group: group
  } do
    assert {:error, {:live_redirect, %{to: "/organize"}}} =
             conn |> login(member) |> live(~p"/organize/#{group.slug}/settings")
  end

  test "transfer rejects wrong confirmation and cancellation leaves ownership unchanged", %{
    conn: conn,
    owner: owner,
    group: group,
    member_membership: membership
  } do
    {:ok, view, _} = conn |> login(owner) |> live(~p"/organize/#{group.slug}/settings")

    view
    |> form("#transfer-ownership-target-form", transfer_target: %{member_id: membership.id})
    |> render_submit()

    view
    |> form("#member-action-form", member_action: %{confirmation: "wrong"})
    |> render_change()

    render_submit(view, "confirm_member_action", %{})
    assert has_element?(view, "#member-action-confirm[disabled]")
    assert has_element?(view, "[role='alert']", "Type the group name exactly")
    view |> element("#member-action-cancel") |> render_click()
    refute has_element?(view, "#member-action-dialog")
    assert has_element?(view, "#ownership-danger-zone")
    assert Ash.get!(Group, group.id, actor: owner).owner_id == owner.id
  end

  test "a mounted settings page loses access when ownership changes elsewhere", %{
    conn: conn,
    owner: owner,
    member: member,
    group: group
  } do
    {:ok, view, _} = conn |> login(owner) |> live(~p"/organize/#{group.slug}/settings")
    assert {:ok, _} = Communities.transfer_group_ownership(group, member.id, actor: owner)
    assert_redirect(view, ~p"/organize/#{group.slug}")
  end

  test "the roster rejects forged transfer controls", %{
    conn: conn,
    owner: owner,
    group: group,
    member_membership: membership
  } do
    {:ok, view, _} = conn |> login(owner) |> live(~p"/organize/#{group.slug}/members")

    render_submit(view, "open_transfer_action", %{
      "transfer_target" => %{"member_id" => membership.id}
    })

    refute has_element?(view, "#member-action-dialog")
    render_click(view, "open_member_action", %{"id" => membership.id, "action" => "transfer"})
    refute has_element?(view, "#member-action-dialog")
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

  test "an already-mounted organizer picker shows newly granted access", %{
    conn: conn,
    owner: owner,
    member: member,
    group: group,
    member_membership: member_membership
  } do
    {:ok, view, _html} =
      conn
      |> login(member)
      |> live(~p"/organize")

    group_link = "a[href='/organize/#{group.slug}']"
    refute has_element?(view, group_link)

    assert {:ok, _membership} =
             Communities.change_member_role(member_membership, :organizer, actor: owner)

    assert has_element?(view, group_link)
  end

  test "an already-mounted organizer picker removes revoked access", %{
    conn: conn,
    owner: owner,
    organizer: organizer,
    group: group,
    organizer_membership: organizer_membership
  } do
    {:ok, view, _html} =
      conn
      |> login(organizer)
      |> live(~p"/organize")

    group_link = "a[href='/organize/#{group.slug}']"
    assert has_element?(view, group_link)

    assert {:ok, _membership} =
             Communities.change_member_role(organizer_membership, :member, actor: owner)

    refute has_element?(view, group_link)
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
