defmodule SimplifiedCalendarNavigationSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Test.Helpers.Authentication

  step "I organize a group named {string}",
       %{args: [name], current_user: user} = context do
    generate(group(name: name, owner_id: user.id, is_public: true, actor: user))
    context
  end

  step "I open the application sidebar", %{session: session} = context do
    Map.put(context, :session, visit(session, "/calendar"))
  end

  step "I visit the legacy My huddlz URL", %{session: session} = context do
    Map.put(context, :session, visit(session, "/my-huddlz"))
  end

  step "I am viewing Calendar", context do
    case context do
      %{session: session} ->
        Map.put(context, :session, visit(session, "/calendar"))

      %{conn: conn} ->
        user = generate(user(role: :user))

        session =
          conn
          |> Authentication.login(user)
          |> visit("/calendar")

        Map.merge(context, %{current_user: user, session: session})
    end
  end

  step "I use the global Discover search", %{session: session} = context do
    session =
      session
      |> fill_in("Search huddlz", with: "coffee")
      |> submit()

    Map.put(context, :session, session)
  end

  step "I am taken to Discover search results using the existing search behavior",
       %{session: session} = context do
    session
    |> assert_path("/discover", query_params: %{"q" => "coffee"})
    |> assert_has(".topbar-search input[name='q'][value='coffee']")

    context
  end

  step "the primary navigation contains {string}, {string}, and {string}",
       %{args: [first, second, third], session: session} = context do
    session
    |> assert_has("#primary-navigation .sb-item", text: first)
    |> assert_has("#primary-navigation .sb-item", text: second)
    |> assert_has("#primary-navigation .sb-item", text: third)

    context
  end

  step "the primary navigation does not contain {string} or {string}",
       %{args: [first, second], session: session} = context do
    session
    |> refute_has("#primary-navigation", text: first)
    |> refute_has("#primary-navigation", text: second)

    context
  end

  step "Calendar has no count badge", %{session: session} = context do
    refute_has(session, "#primary-navigation a[href='/calendar'] .badge")
    context
  end

  step "{string} appears in a visually separate {string} section",
       %{args: [group_name, section_name], session: session} = context do
    session
    |> assert_has("#organize-navigation-label", text: section_name)
    |> assert_has(
      "#organize-navigation[aria-labelledby='organize-navigation-label'] .sb-org-row",
      text: group_name
    )

    context
  end
end
