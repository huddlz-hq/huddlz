defmodule AdminImpersonationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  step "I am told I cannot edit {string}", %{args: [name], session: session} = context do
    group = find_group(name)

    session
    |> assert_path("/groups/#{group.slug}")
    |> assert_has("*", text: "You don't have permission to edit this group")

    context
  end

  step "{string} cannot rename {string} through the API", %{args: [email, name]} = context do
    group = find_group(name)

    response =
      gql_as(
        email,
        ~s|mutation { updateGroup(id: "#{group.id}", input: {name: "Renamed"}) { result { id } errors { message } } }|
      )

    assert response["data"]["updateGroup"]["result"] == nil
    assert response["data"]["updateGroup"]["errors"] != []
    assert to_string(find_group(name).name) == name
    context
  end

  step "{string} cannot transfer ownership of {string}", %{args: [email, name]} = context do
    group = find_group(name)
    target = find_user("member554@example.com")

    assert {:error, %Ash.Error.Forbidden{}} =
             Huddlz.Communities.transfer_group_ownership(group, target.id,
               actor: find_user(email)
             )

    assert find_group(name).owner_id == group.owner_id
    context
  end

  step "I am offered to schedule a huddl", %{session: session} = context do
    assert_has(session, "button", text: "Schedule huddl")
    context
  end

  step "I choose to view as {string}", %{args: [email], session: session} = context do
    session = click_link(session, "View as #{email}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I am viewing huddlz as {string}", %{args: [email]} = context do
    admin = Enum.find(context.users, &(to_string(&1.email) == "admin554@example.com"))

    session =
      Phoenix.ConnTest.build_conn()
      |> Huddlz.Test.Helpers.Authentication.login(admin)
      |> visit("/admin/users")
      |> click_link("View as #{email}")

    Map.merge(context, %{conn: session, session: session, current_user: admin})
  end

  step "every page says I am viewing as {string}", %{args: [name], session: session} = context do
    session
    |> assert_has("#impersonation-bar", text: "Viewing huddlz as #{name}")
    |> visit("/groups")
    |> assert_has("#impersonation-bar", text: "Viewing huddlz as #{name}")

    context
  end

  step "no page says I am viewing as {string}", %{args: [name], session: session} = context do
    session
    |> refute_has("#impersonation-bar")
    |> visit("/agenda")
    |> refute_has("#impersonation-bar", text: name)

    context
  end

  step "the sidebar shows me as {string}", %{args: [name], session: session} = context do
    assert_has(session, "#sidebar-user", text: name)
    context
  end

  step "I stop viewing as {string}", %{args: [name], session: session} = context do
    assert_has(session, "#impersonation-bar a", text: "Stop viewing as #{name}")
    session = click_link(session, "Stop viewing as #{name}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I am on the users page", %{session: session} = context do
    assert_path(session, "/admin/users")
    context
  end

  step "I try to view as {string}", %{args: [email]} = context do
    target = find_user(email)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Huddlz.Test.Helpers.Authentication.login(context.current_user)
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> Phoenix.ConnTest.dispatch(
        HuddlzWeb.Endpoint,
        :post,
        "/admin/impersonations/#{target.id}"
      )

    session = visit(Phoenix.ConnTest.recycle(conn), Phoenix.ConnTest.redirected_to(conn))
    Map.merge(context, %{conn: session, session: session})
  end

  step "I am not offered to view as {string}", %{args: [email], session: session} = context do
    refute_has(session, "a", text: "View as #{email}")
    refute_has(session, "[aria-label='View as #{email}']")
    context
  end

  step "I am offered to view as {string}", %{args: [email], session: session} = context do
    assert_has(session, "[aria-label='View as #{email}']")
    context
  end

  step "I RSVP to {string}", %{args: [title], session: session} = context do
    huddl = find_huddl(title)

    session =
      session
      |> visit("/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")
      |> click_button("RSVP to this huddl")

    Map.merge(context, %{conn: session, session: session})
  end

  step "the record shows {string} viewed as {string} and stopped",
       %{args: [admin_email, email]} = context do
    admin = find_user(admin_email)
    user = find_user(email)

    record =
      Huddlz.Admin.Impersonation
      |> Ash.Query.filter(admin_id == ^admin.id and user_id == ^user.id)
      |> Ash.read_one!(actor: admin)

    assert record.ended_at
    assert DateTime.compare(record.ended_at, record.started_at) != :lt
    Map.put(context, :impersonation, record)
  end

  step "the RSVP by {string} to {string} is attributed to that viewing",
       %{args: [email, title]} = context do
    user = find_user(email)
    huddl = find_huddl(title)

    activity =
      Huddlz.Communities.GroupActivity
      |> Ash.Query.filter(user_id == ^user.id and huddl_id == ^huddl.id and kind == :rsvped)
      |> Ash.read_one!(authorize?: false)

    assert activity.impersonation_id == context.impersonation.id
    context
  end

  defp find_huddl(title) do
    Huddlz.Communities.Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end

  defp gql_as(email, query) do
    build_conn()
    |> authenticated_conn(find_user(email))
    |> gql_post(query)
    |> json_response(200)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end
