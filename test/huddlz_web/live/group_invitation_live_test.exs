defmodule HuddlzWeb.GroupInvitationLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL
  alias Huddlz.Communities

  setup do
    owner = generate(user())
    invitee = generate(user())

    group =
      generate(
        group(
          name: "Private Invitation Group #{System.unique_integer([:positive])}",
          owner_id: owner.id,
          actor: owner,
          is_public: false
        )
      )

    %{owner: owner, invitee: invitee, group: group}
  end

  test "owner sends an invitation and the invitee accepts it", context do
    %{conn: conn, owner: owner, invitee: invitee, group: group} = context

    {:ok, organizer_view, _html} =
      conn
      |> login(owner)
      |> live(~p"/organize/#{group.slug}/members")

    organizer_view
    |> form("#group-invitation-form",
      invitation: %{email: to_string(invitee.email), role: "member"}
    )
    |> render_submit()

    assert has_element?(organizer_view, "#invitation-rows", invitee.display_name)

    invitation =
      Communities.list_my_group_invitations!(actor: invitee)
      |> List.first()

    {:ok, invitation_view, _html} =
      build_conn()
      |> login(invitee)
      |> live(~p"/invitations/#{invitation.id}")

    assert has_element?(invitation_view, "#accept-invitation")
    assert has_element?(invitation_view, "#back-to-invitations", "Back to invitations")
    assert has_element?(invitation_view, "#invitation-status-description", "stays hidden")
    refute has_element?(invitation_view, "#open-invited-group")

    invitation_view
    |> element("#accept-invitation")
    |> render_click()

    assert has_element?(invitation_view, "#open-invited-group")

    assert has_element?(
             invitation_view,
             "#invitation-status-description",
             "You accepted this invitation."
           )

    refute has_element?(invitation_view, "#accept-invitation")

    assert Communities.get_membership_in_group!(group.id, actor: invitee).role == :member
    assert Enum.any?(Communities.my_groups!(:all, actor: invitee), &(&1.id == group.id))
  end

  test "invitation page keeps the unread notification badge", context do
    %{conn: conn, owner: owner, invitee: invitee, group: group} = context

    invitation =
      Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    {:ok, view, _html} =
      conn
      |> login(invitee)
      |> live(~p"/invitations/#{invitation.id}")

    assert has_element?(
             view,
             ~s|#notification-nav-link[aria-label="Notifications, 1 unread"]|
           )

    assert has_element?(view, "#notification-nav-badge", "1")
  end

  test "invitee declines an invitation", context do
    %{conn: conn, owner: owner, invitee: invitee, group: group} = context

    invitation = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    {:ok, view, _html} =
      conn
      |> login(invitee)
      |> live(~p"/invitations/#{invitation.id}")

    assert has_element?(view, "#decline-invitation")

    view
    |> element("#decline-invitation")
    |> render_click()

    assert has_element?(view, "#flash-info", "Invitation declined.")
    assert has_element?(view, "span.pill", "Declined")
    assert has_element?(view, "#invitation-status-description", "You declined this invitation.")
    refute has_element?(view, "#accept-invitation")
    refute has_element?(view, "#decline-invitation")
  end

  test "accepting a concurrently revoked invitation shows the revoked status, not a stale pending view",
       context do
    %{conn: conn, owner: owner, invitee: invitee, group: group} = context

    invitation = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    {:ok, view, _html} =
      conn
      |> login(invitee)
      |> live(~p"/invitations/#{invitation.id}")

    Communities.revoke_group_invitation!(invitation, actor: owner)

    view
    |> element("#accept-invitation")
    |> render_click()

    assert has_element?(view, "#flash-error", "This invitation was revoked.")
    assert has_element?(view, "span.pill", "Revoked")
    refute has_element?(view, "#accept-invitation")
  end

  test "declining a concurrently revoked invitation shows the revoked status, not a stale pending view",
       context do
    %{conn: conn, owner: owner, invitee: invitee, group: group} = context

    invitation = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    {:ok, view, _html} =
      conn
      |> login(invitee)
      |> live(~p"/invitations/#{invitation.id}")

    Communities.revoke_group_invitation!(invitation, actor: owner)

    view
    |> element("#decline-invitation")
    |> render_click()

    assert has_element?(view, "#flash-error", "This invitation was revoked.")
    assert has_element?(view, "span.pill", "Revoked")
    refute has_element?(view, "#decline-invitation")
  end

  test "accepting a concurrently expired invitation shows the expired status, not a stale pending view",
       context do
    %{conn: conn, owner: owner, invitee: invitee, group: group} = context

    invitation = Communities.invite_to_group!(group.id, invitee.id, :member, actor: owner)

    {:ok, view, _html} =
      conn
      |> login(invitee)
      |> live(~p"/invitations/#{invitation.id}")

    expire_in_database(invitation)

    view
    |> element("#accept-invitation")
    |> render_click()

    assert has_element?(view, "#flash-error", "This invitation expired.")
    assert has_element?(view, "span.pill", "Expired")
    refute has_element?(view, "#accept-invitation")
  end

  test "organizers only see the member role option", context do
    %{conn: conn, owner: owner, invitee: invitee, group: group} = context
    organizer = generate(user())

    generate(
      group_member(
        group_id: group.id,
        user_id: organizer.id,
        role: :organizer,
        actor: owner
      )
    )

    {:ok, view, _html} =
      conn
      |> login(organizer)
      |> live(~p"/organize/#{group.slug}/members")

    assert has_element?(view, "#group-invitation-form option[value='member']")
    refute has_element?(view, "#group-invitation-form option[value='organizer']")

    assert Communities.list_my_group_invitations!(actor: invitee) == []
  end

  test "public groups do not show the invitation form", context do
    %{conn: conn, owner: owner} = context

    group =
      generate(
        group(
          name: "Public Invitation UI #{System.unique_integer([:positive])}",
          owner_id: owner.id,
          actor: owner,
          is_public: true
        )
      )

    {:ok, view, _html} =
      conn
      |> login(owner)
      |> live(~p"/organize/#{group.slug}/members")

    refute has_element?(view, "#group-invitations")
    refute has_element?(view, "#group-invitation-form")
  end

  defp expire_in_database(invitation) do
    expires_at = DateTime.add(DateTime.utc_now(), -1, :day)

    SQL.query!(
      Huddlz.Repo,
      "UPDATE group_invitations SET expires_at = $1 WHERE id = $2",
      [expires_at, Ecto.UUID.dump!(invitation.id)]
    )
  end
end
