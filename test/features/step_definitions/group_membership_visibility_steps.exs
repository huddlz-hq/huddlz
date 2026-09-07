defmodule GroupMembershipVisibilitySteps do
  use Cucumber.StepDefinition
  import Huddlz.Generator
  import PhoenixTest
  import Huddlz.Test.Helpers.Authentication

  step "I accept my invitation to {string} in another session", %{args: [name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))

    invitation =
      Huddlz.Communities.list_my_group_invitations!(actor: context.current_user)
      |> Enum.find(&(&1.group_id == group.id))

    Phoenix.ConnTest.build_conn()
    |> login(context.current_user)
    |> visit("/invitations/#{invitation.id}")
    |> click_button("Accept invitation")
    |> assert_has("main", text: "You accepted this invitation.")

    context
  end

  step "I open the promotion confirmation for {string}", %{args: [name]} = context do
    session =
      within(context.session, "[aria-label='Manage #{name}']", fn session ->
        click_button(session, "Promote")
      end)

    assert_has(session, "#member-action-dialog")
    Map.merge(context, %{session: session, conn: session})
  end

  step "the membership action confirmation should be closed", context do
    refute_has(context.session, "#member-action-dialog")
    context
  end

  step "the leave confirmation should explain that RSVPs are preserved", context do
    assert_has(context.session, "#leave-group-dialog",
      text: "Leaving does not cancel your existing RSVPs."
    )

    context
  end

  step "I transfer {string} to {string} in another session", %{args: [name, email]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))
    target = Enum.find(context.users, &(to_string(&1.email) == email))

    Phoenix.ConnTest.build_conn()
    |> login(context.current_user)
    |> visit("/organize/#{group.slug}/members")
    |> select("New owner", option: target.display_name)
    |> click_button("Transfer group ownership")
    |> fill_in("Type #{name} to confirm", with: name)
    |> click_button("Transfer ownership")

    context
  end

  step "I try to open the private huddl directly", context do
    huddl = context.private_huddl
    group = Enum.find(context.groups, &(&1.id == huddl.group_id))

    {404, _headers, body} =
      Phoenix.ConnTest.assert_error_sent(404, fn ->
        context.session.conn
        |> Phoenix.ConnTest.dispatch(
          HuddlzWeb.Endpoint,
          :get,
          "/groups/#{group.slug}/huddlz/#{huddl.id}"
        )
      end)

    Map.put(context, :error_body, body)
  end

  step "{string} has an organizer invitation to {string}", %{args: [email, name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))
    owner = Enum.find(context.users, &(&1.id == group.owner_id))
    invitee = Enum.find(context.users, &(to_string(&1.email) == email))
    Huddlz.Communities.invite_to_group!(group.id, invitee.id, :organizer, actor: owner)
    context
  end

  step "I should have no group role label", context do
    refute_has(context.session, ".role-pill")
    context
  end

  step "the owner promotes me in {string} in another session", %{args: [group_name]} = context do
    manage_current_member(context, group_name, "Promote", "Promote to organizer")
  end

  step "my group role should be {string}", %{args: [role]} = context do
    assert_has(context.session, ".role-pill", text: role)
    context
  end

  step "my card role for {string} should be {string}", %{args: [name, role]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))
    assert_has(context.session, "a[href='/groups/#{group.slug}'] .card-tag", text: role)
    context
  end

  step "my navigation role for {string} should be {string}", %{args: [name, role]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))
    assert_has(context.session, ".sb-org-row[href='/organize/#{group.slug}']", text: role)
    context
  end

  step "I leave {string} in another session", %{args: [group_name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == group_name))

    Phoenix.ConnTest.build_conn()
    |> login(context.current_user)
    |> visit("/groups/#{group.slug}")
    |> click_button("Leave Group")
    |> click_button("Yes, leave group")

    context
  end

  step "the organizer roster should be inaccessible", context do
    unwrap(context.session, fn view ->
      Phoenix.LiveViewTest.assert_redirect(view, "/organize")
      ""
    end)

    context
  end

  step "a past members-only huddl {string} exists in {string}",
       %{args: [title, group_name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == group_name))

    generate(
      past_huddl(title: title, group_id: group.id, creator_id: group.owner_id, is_private: true)
    )

    context
  end

  step "the owner removes me from {string} in another session", %{args: [group_name]} = context do
    manage_current_member(context, group_name, "Remove", "Remove from group")
  end

  step "the owner demotes me in {string} in another session", %{args: [group_name]} = context do
    manage_current_member(context, group_name, "Demote", "Demote to member")
  end

  step "the leave confirmation should be closed", context do
    refute_has(context.session, "#leave-group-dialog")
    context
  end

  step "the huddl creation action should be visible", context do
    assert_has(context.session, "a[href$='/huddlz/new']")
    context
  end

  step "the huddl creation action should be hidden", context do
    refute_has(context.session, "a[href$='/huddlz/new']")
    context
  end

  step "I submit stale group interactions", context do
    session =
      unwrap(context.session, fn view ->
        Phoenix.LiveViewTest.render_click(view, "leave_group", %{})
        Phoenix.LiveViewTest.render_click(view, "change_past_page", %{"page" => "1"})
        Phoenix.LiveViewTest.render_click(view, "switch_tab", %{"tab" => "upcoming"})
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  defp manage_current_member(context, group_name, action, confirmation) do
    group = Enum.find(context.groups, &(to_string(&1.name) == group_name))
    owner = Enum.find(context.users, &(&1.id == group.owner_id))

    Phoenix.ConnTest.build_conn()
    |> login(owner)
    |> visit("/organize/#{group.slug}/members")
    |> within("[aria-label='Manage #{context.current_user.display_name}']", fn session ->
      click_button(session, action)
    end)
    |> click_button(confirmation)

    context
  end

  step "I open the organizer roster for {string}", %{args: [group_name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == group_name))
    session = visit(context[:session] || context.conn, "/organize/#{group.slug}/members")
    Map.merge(context, %{session: session, conn: session})
  end

  step "the group edit action should be hidden", context do
    refute_has(context.session, "a", text: "Edit group")
    context
  end

  step "I should see the huddl card {string}", %{args: [title]} = context do
    assert_has(context.session, ".card-title", text: title)
    context
  end

  step "I should not see the huddl card {string}", %{args: [title]} = context do
    refute_has(context.session, ".card-title", text: title)
    context
  end

  step "group member identities should be hidden", context do
    refute_has(context.session, "#member-grid .member-mark")
    context
  end

  step "I should see the group member {string}", %{args: [name]} = context do
    assert_has(context.session, "#member-grid .member-mark[title='#{name}']")
    context
  end

  step "a members-only huddl {string} exists in {string}",
       %{args: [title, group_name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == group_name))
    owner = Enum.find(context.users, &(&1.id == group.owner_id))

    private_huddl =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: owner.id,
          is_private: true,
          actor: owner
        )
      )

    Map.put(context, :private_huddl, private_huddl)
  end
end
