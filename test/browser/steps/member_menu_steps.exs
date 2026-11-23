defmodule BrowserMemberMenuSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Fluffy.PhoenixTest

  step "I have opened a group's roster in a browser", context do
    owner = generate(user(role: :user, display_name: "Owner Olive"))
    member = generate(user(role: :user, display_name: "Member Maya"))

    {group, _memberships} =
      generate_group_with_members(
        owner: owner,
        group: [name: "Roster Keyboard", slug: "roster-keyboard"],
        members: [%{user: member, role: :member}]
      )

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/organize/#{group.slug}/members")
      |> assert_has("h1", text: "Members")

    Map.merge(context, %{conn: conn, owner: owner, member: member, group: group})
  end

  step "I open the menu for {string} with the keyboard", %{args: [name]} = context do
    conn =
      context.conn
      |> unwrap(&Playwright.Page.press!(&1, trigger_for(name), "Enter"))
      |> assert_browser(menu_open(name))

    Map.merge(context, %{conn: conn, menu_name: name})
  end

  step "I choose {string} with the keyboard", %{args: [label]} = context do
    conn = tab_to_item(context.conn, label)
    Map.put(context, :conn, unwrap(conn, &Playwright.Page.press!(&1, ":focus", "Enter")))
  end

  step "the member menu is closed and focus is back on its button", context do
    name = context.menu_name

    conn =
      context.conn
      |> assert_browser("!#{menu_open(name)}")
      |> assert_has("#{trigger_for(name)}:focus")

    Map.put(context, :conn, conn)
  end

  step "the promotion confirmation is open and the menu is closed", context do
    conn =
      context.conn
      |> assert_has("[role='dialog']", text: "Promote #{context.menu_name}?")
      |> assert_browser("!#{menu_open(context.menu_name)}")

    Map.put(context, :conn, conn)
  end

  defp trigger_for(name), do: "button[aria-label='Manage #{name}']"

  defp menu_open(name),
    do:
      "document.querySelector(\"[role='menu'][aria-label='Manage #{name}']\").matches(':popover-open')"

  # Tab from the trigger into the menu, one item at a time, until the wanted
  # one has focus.
  defp tab_to_item(conn, label, tries \\ 4)

  defp tab_to_item(_conn, label, 0), do: flunk("no menu item labelled #{label}")

  defp tab_to_item(conn, label, tries) do
    conn = unwrap(conn, &Playwright.Page.press!(&1, ":focus", "Tab"))

    focused =
      unwrap_and_return(
        conn,
        &Playwright.Page.evaluate!(&1, "document.activeElement.textContent.trim()")
      )

    if focused == label, do: conn, else: tab_to_item(conn, label, tries - 1)
  end
end
