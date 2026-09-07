defmodule BrowserOrganizerSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  step "I have opened a new huddl as its group organizer", context do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/groups/#{group.slug}/huddlz/new")
      |> assert_has(".phx-connected")

    Map.put(context, :conn, conn)
  end

  step "I tab into the format choices and choose virtual with an arrow key", context do
    conn =
      context.conn
      |> press("textarea[name='form[description]']", "Tab")
      |> assert_has("#event-type-in_person:focus")
      |> press(":focus", "ArrowRight")

    Map.put(context, :conn, conn)
  end

  step "the virtual choice has visible keyboard focus and reveals the online link", context do
    context.conn
    |> assert_has("#event-type-virtual:checked:focus-visible")
    |> assert_has("input[name='form[virtual_link]']")
    |> assert_browser("""
    getComputedStyle(document.querySelector('#event-type-virtual').closest('.event-type-option')).outlineStyle !== 'none'
    """)

    context
  end

  step "I enable recurrence and members only using Space", context do
    conn =
      context.conn
      |> press("select[name='form[duration_minutes]']", "Tab")
      |> assert_has("input[name='form[is_recurring]']:focus")
      |> press(":focus", "Space")
      |> assert_has("input[name='form[is_recurring]']:checked:focus-visible[aria-checked='true']")
      |> assert_has("select[name='form[frequency]']")
      |> press("input[name='form[max_attendees]']", "Tab")
      |> assert_has("input[name='form[is_private]']:focus")
      |> press(":focus", "Space")

    Map.put(context, :conn, conn)
  end

  step "both switches stay focused when changed and expose their checked state", context do
    context.conn
    |> assert_has("input[name='form[is_recurring]']:checked[aria-checked='true']")
    |> assert_has("input[name='form[is_private]']:checked:focus-visible[aria-checked='true']")
    |> assert_browser("""
    getComputedStyle(document.querySelector('input[name="form[is_private]"] + .track')).boxShadow !== 'none'
    """)

    context
  end
end
