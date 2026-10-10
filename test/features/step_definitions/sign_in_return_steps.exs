defmodule SignInReturnSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest
  import ExUnit.Assertions

  step "I am signed out looking at a public huddl for a return visit", context do
    {member, owner, group} = return_visit_fixtures()

    huddl =
      generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner, is_private: false))

    path = "/groups/#{group.slug}/huddlz/#{huddl.id}"
    session = visit(context.conn, path)

    Map.merge(context, %{
      session: session,
      return_member: member,
      return_huddl: huddl,
      return_path: path
    })
  end

  step "I choose Sign in from the page header", context do
    Map.put(context, :session, click_link(context.session, ".content-actions a", "Sign in"))
  end

  step "I am signed out looking at a public group's Past huddlz for a return visit", context do
    {member, owner, group} = return_visit_fixtures()

    generate(
      past_huddl(
        group_id: group.id,
        creator_id: owner.id,
        title: "Return archive",
        starts_at: DateTime.add(DateTime.utc_now(), -2, :day),
        ends_at: DateTime.add(DateTime.utc_now(), -2, :day) |> DateTime.add(3600)
      )
    )

    session =
      context.conn
      |> visit("/groups/#{group.slug}")
      |> click_link("Past")
      |> assert_has("h3", text: "Return archive")

    Map.merge(context, %{session: session, return_member: member, return_group: group})
  end

  step "I sign in for the return visit", context do
    Map.put(context, :session, sign_in(context.session, context.return_member, "Password123!"))
  end

  step "I sign in with the wrong password for the return visit", context do
    session =
      context.session
      |> sign_in(context.return_member, "IncorrectPassword123!")
      |> assert_has("*", text: "Incorrect email or password")

    Map.put(context, :session, session)
  end

  step "I return to the group's Past huddlz", context do
    context.session
    |> assert_path("/groups/#{context.return_group.slug}", query_params: %{tab: "past"})
    |> assert_has("h3", text: "Return archive")

    context
  end

  step "I land on my agenda instead", context do
    assert_path(context.session, "/agenda")
    context
  end

  step "I return to that huddl without reserving a spot", context do
    context.session
    |> assert_path(context.return_path)
    |> assert_has("h1", text: context.return_huddl.title)
    |> assert_has("button", text: "RSVP")

    assert [] =
             Huddlz.Communities.check_user_rsvp!(context.return_huddl.id,
               actor: context.return_member
             )

    context
  end

  step "I open my saved Discover search for the return visit", context do
    path =
      "/discover?" <>
        URI.encode_query(
          q: "Elixir/Phoenix",
          time_zone: "America/New_York",
          event_type: "virtual"
        )

    Map.put(context, :session, visit(context.session, path))
  end

  step "I return to the same Discover search", context do
    context.session
    |> assert_path("/discover",
      query_params: %{
        "q" => "Elixir/Phoenix",
        "time_zone" => "America/New_York",
        "event_type" => "virtual"
      }
    )
    |> assert_has("input", value: "Elixir/Phoenix")

    context
  end

  step "I open my saved attending search for the return visit", context do
    Map.put(
      context,
      :session,
      visit(context.session, "/discover?yours=attending&q=Elixir%2FPhoenix&event_type=virtual")
    )
  end

  step "I return to the same attending search", context do
    context.session
    |> assert_path("/discover",
      query_params: %{yours: "attending", q: "Elixir/Phoenix", event_type: "virtual"}
    )
    |> assert_has("h1", text: "huddlz you're attending")
    |> assert_has("input", value: "Elixir/Phoenix")

    context
  end

  step "I open an expired email-change link for the return visit", context do
    Map.put(context, :session, visit(context.session, "/email-change/expired-return-visit"))
  end

  step "I return to the email-change page", context do
    context.session
    |> assert_path("/email-change/expired-return-visit")
    |> assert_has("h1", text: "Approve email change")
    |> assert_has("p", text: "This approval link is invalid, expired, or already used.")

    context
  end

  defp return_visit_fixtures do
    member =
      generate(user_with_password()) |> Ash.Seed.update!(%{confirmed_at: DateTime.utc_now()})

    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
    {member, owner, group}
  end

  defp sign_in(session, member, password) do
    session
    |> fill_in("Email", with: to_string(member.email))
    |> fill_in("Password", with: password)
    |> click_button("Sign in")
  end
end
