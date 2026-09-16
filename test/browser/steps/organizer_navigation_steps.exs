defmodule BrowserOrganizerNavigationSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [evaluate: 3]

  step "I have opened the workspace picker for my group", context do
    owner = generate(user(role: :user))
    group = generate(group(name: "Navigation group", owner_id: owner.id, actor: owner))

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/organize")
      |> assert_has(".phx-connected")
      |> assert_has("h1", text: "Organizer workspace")

    evaluate(conn, "window.__organizerNavigation = 'kept'", fn _ -> :ok end)
    Map.merge(context, %{conn: conn, group: group})
  end

  step "I open my group workspace", context do
    Map.put(context, :conn, click_link(context.conn, "main a", context.group.name))
  end

  step "the group workspace arrives without reloading the page", context do
    conn =
      context.conn
      |> assert_path("/organize/#{context.group.slug}")
      |> assert_has("main a", text: "Edit group")
      |> assert_browser("window.__organizerNavigation === 'kept'")

    Map.put(context, :conn, conn)
  end

  step "I follow the workspace link {string}", %{args: [label]} = context do
    Map.put(context, :conn, click_link(context.conn, "main a", label))
  end

  step "the {string} form arrives without reloading the page", %{args: [heading]} = context do
    conn =
      context.conn
      |> assert_has("h1", text: heading)
      |> assert_browser("window.__organizerNavigation === 'kept'")

    Map.put(context, :conn, conn)
  end
end
