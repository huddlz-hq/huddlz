defmodule HuddlzWeb.OrganizeLivePermissionsTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Huddlz.Communities
  alias Huddlz.Communities.MembershipEvents

  setup do
    owner = generate(user(role: :user))
    organizer = generate(user(role: :user))
    member = generate(user(role: :user))
    admin = generate(user(role: :admin))

    {group, [organizer_membership, _member_membership]} =
      generate_group_with_members(
        owner: owner,
        group: [name: "Permission-aware Group", is_public: true],
        members: [
          %{user: organizer, role: :organizer},
          %{user: member, role: :member}
        ]
      )

    huddl =
      generate(
        huddl(
          title: "Permission-aware Huddl",
          group_id: group.id,
          creator_id: owner.id,
          actor: owner
        )
      )

    %{
      admin: admin,
      group: group,
      huddl: huddl,
      member: member,
      organizer: organizer,
      organizer_membership: organizer_membership,
      owner: owner
    }
  end

  test "owner sees each action permitted by the domain", %{
    conn: conn,
    group: group,
    huddl: huddl,
    owner: owner
  } do
    {:ok, overview, _html} = live(login(conn, owner), ~p"/organize/#{group.slug}")

    assert has_element?(
             overview,
             "#organize-edit-group[href='/groups/#{group.slug}/edit']"
           )

    assert has_element?(
             overview,
             "#organize-create-huddl[href='/groups/#{group.slug}/huddlz/new']"
           )

    {:ok, huddlz_view, _html} =
      live(login(conn, owner), ~p"/organize/#{group.slug}/huddlz")

    assert has_element?(
             huddlz_view,
             "#organize-schedule-huddl[href='/groups/#{group.slug}/huddlz/new']"
           )

    assert has_element?(
             huddlz_view,
             "#organize-edit-huddl-#{huddl.id}[href='/groups/#{group.slug}/huddlz/#{huddl.id}/edit']"
           )
  end

  test "organizer sees huddl actions but not owner-only group editing", %{
    conn: conn,
    group: group,
    huddl: huddl,
    organizer: organizer
  } do
    {:ok, overview, _html} = live(login(conn, organizer), ~p"/organize/#{group.slug}")

    refute has_element?(overview, "#organize-edit-group")
    assert has_element?(overview, "#organize-create-huddl")

    {:ok, members_view, _html} =
      live(login(conn, organizer), ~p"/organize/#{group.slug}/members")

    refute has_element?(members_view, "#organize-edit-group")

    {:ok, huddlz_view, _html} =
      live(login(conn, organizer), ~p"/organize/#{group.slug}/huddlz")

    assert has_element?(huddlz_view, "#organize-schedule-huddl")
    assert has_element?(huddlz_view, "#organize-edit-huddl-#{huddl.id}")
  end

  test "admin sees actions allowed by the policy bypass", %{
    conn: conn,
    group: group,
    admin: admin
  } do
    {:ok, view, _html} = live(login(conn, admin), ~p"/organize/#{group.slug}")

    assert has_element?(view, "#organize-edit-group")
    assert has_element?(view, "#organize-create-huddl")
  end

  test "member and signed-out person cannot enter the workspace", %{
    conn: conn,
    group: group,
    member: member
  } do
    assert {:error, {:live_redirect, %{to: "/organize"}}} =
             live(login(conn, member), ~p"/organize/#{group.slug}")

    assert {:error, {:redirect, %{to: "/sign-in"}}} =
             live(conn, ~p"/organize/#{group.slug}")
  end

  test "organizer remains blocked from the direct group edit route", %{
    conn: conn,
    group: group,
    organizer: organizer
  } do
    conn
    |> login(organizer)
    |> visit(~p"/groups/#{group.slug}/edit")
    |> assert_has("*", text: "You don't have permission to edit this group")
    |> refute_has("#edit-group-form")
  end

  test "demotion removes an already-mounted organizer workspace", %{
    conn: conn,
    group: group,
    organizer: organizer,
    organizer_membership: organizer_membership,
    owner: owner
  } do
    Process.flag(:trap_exit, true)
    :ok = MembershipEvents.subscribe(group.id)
    group_id = group.id

    {:ok, view, _html} =
      live(login(conn, organizer), ~p"/organize/#{group.slug}/members")

    assert has_element?(view, "h1", "Members")
    refute has_element?(view, "#organize-edit-group")

    assert {:ok, %{role: :member}} =
             Communities.change_member_role(organizer_membership, :member, actor: owner)

    assert {:error, _reason} =
             Communities.get_group_for_organize(group.slug, actor: organizer)

    assert_receive {:group_membership_changed, ^group_id}

    assert_receive {_ref, {:redirect, _live_view_topic, %{kind: :push, to: "/organize"}}}
  end

  test "ownership transfer reveals the owner action in an already-mounted workspace", %{
    conn: conn,
    group: group,
    organizer: organizer,
    owner: owner
  } do
    {:ok, view, _html} = live(login(conn, organizer), ~p"/organize/#{group.slug}")
    refute has_element?(view, "#organize-edit-group")

    assert {:ok, _group} =
             Communities.transfer_group_ownership(group, organizer.id, actor: owner)

    assert has_element?(view, "#organize-edit-group")
  end
end
