defmodule BrowserOrganizerSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Fluffy.Playwright.Keyboard

  step "I have opened a new huddl as its group organizer", %{session: session} do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    session
    |> sign_in(owner)
    |> visit("/groups/#{group.slug}/huddlz/new")

    :ok
  end

  step "I tab into the format choices and choose virtual with an arrow key", %{session: session} do
    session
    |> press(by_label("Description", exact: true), "Tab")
    |> assert(focused(by_role(:radio, name: "In person", exact: true)))
    |> Keyboard.press("ArrowRight")

    :ok
  end

  step "the virtual choice has visible keyboard focus and reveals the online link",
       %{session: session} do
    virtual = by_role(:radio, name: "Virtual", exact: true)

    session
    |> assert(checked(virtual))
    |> assert(attached(focus_visible(virtual)))
    |> assert(visible(by_label("Online link", exact: true)))
    |> assert_browser("""
    getComputedStyle(document.querySelector('#event-type-virtual').closest('.event-type-option')).outlineStyle !== 'none'
    """)

    :ok
  end

  step "I enable recurrence and members only using Space", %{session: session} do
    session
    |> press(by_label("Duration", exact: true), "Tab")
    |> assert(focused(recurring()))
    |> Keyboard.press("Space")
    |> assert(checked(recurring()))
    |> assert(attached(focus_visible(recurring())))
    |> assert(attribute(recurring(), "aria-checked", "true"))
    |> assert(visible(by_label("Frequency", exact: true)))
    |> press(by_label("Max attendees", exact: true), "Tab")
    |> assert(focused(members_only()))
    |> Keyboard.press("Space")

    :ok
  end

  step "both switches stay focused when changed and expose their checked state",
       %{session: session} do
    session
    |> assert(checked(recurring()))
    |> assert(attribute(recurring(), "aria-checked", "true"))
    |> assert(checked(members_only()))
    |> assert(attached(focus_visible(members_only())))
    |> assert(attribute(members_only(), "aria-checked", "true"))
    |> assert_browser("""
    getComputedStyle(document.querySelector('input[name="form[is_private]"] + .track')).boxShadow !== 'none'
    """)

    :ok
  end

  defp recurring, do: by_role(:switch, name: "Recurring huddl", exact: true)
  defp members_only, do: by_role(:switch, name: "Members only", exact: true)
  defp focus_visible(locator), do: and_(locator, by_css(":focus-visible"))
end
