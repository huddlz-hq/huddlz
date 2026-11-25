defmodule BrowserMemberMenuSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 2, step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Fluffy.Playwright.Keyboard

  step "I have opened a group's roster in a browser", %{session: session} do
    owner = generate(user(role: :user, display_name: "Owner Olive"))
    member = generate(user(role: :user, display_name: "Member Maya"))

    {group, _memberships} =
      generate_group_with_members(
        owner: owner,
        group: [name: "Roster Keyboard", slug: "roster-keyboard"],
        members: [%{user: member, role: :member}]
      )

    session
    |> sign_in(owner)
    |> visit("/organize/#{group.slug}/members")
    |> assert(visible(by_role(:heading, level: 1, name: "Members")))

    %{owner: owner, member: member, group: group}
  end

  step "I open the menu for {string} with the keyboard", %{args: [name], session: session} do
    session
    |> press(trigger(name), "Enter")
    |> assert(visible(menu(name)))

    %{menu_name: name}
  end

  step "I choose {string} with the keyboard", %{args: [label], session: session} do
    session
    |> tab_to_item(label)
    |> Keyboard.press("Enter")

    :ok
  end

  step "the member menu is closed and focus is back on its button",
       %{session: session, menu_name: name} do
    session
    |> refute(visible(menu(name)))
    |> assert(focused(trigger(name)))

    :ok
  end

  step "the promotion confirmation is open and the menu is closed",
       %{session: session, menu_name: name} do
    session
    |> assert(visible(by_role(:dialog) |> filter(has_text: "Promote #{name}?")))
    |> refute(visible(menu(name)))

    :ok
  end

  defp trigger(name), do: by_role(:button, name: "Manage #{name}", exact: true)
  defp menu(name), do: by_role(:menu, name: "Manage #{name}", exact: true)

  # Tab from the trigger into the menu, one item at a time, until the wanted
  # one has focus.
  defp tab_to_item(session, label, tries \\ 4)

  defp tab_to_item(_session, label, 0), do: flunk("no menu item labelled #{label}")

  defp tab_to_item(session, label, tries) do
    session = Keyboard.press(session, "Tab")
    focused = Fluffy.Playwright.evaluate(session, "document.activeElement.textContent.trim()")
    if focused == label, do: session, else: tab_to_item(session, label, tries - 1)
  end
end
