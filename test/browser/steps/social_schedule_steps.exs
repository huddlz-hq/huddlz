defmodule BrowserSocialScheduleSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Fluffy.Playwright

  step "I am editing a social connection as its owner", %{session: session} do
    {session, group, _place} = connected_place(session)

    session
    |> visit("/organize/#{group.slug}/social")
    |> click(edit())
    |> assert_has(preview() |> filter(has_text: "Morning-of post preview"))
    # The sheet moves focus to its first control again two animation
    # frames after mounting; wait for it to finish opening before typing.
    |> assert(css(sheet(), "opacity", "1"))

    :ok
  end

  step "I ask to remove the place and cancel", %{session: session} do
    session
    |> click(by_role(:button, name: "Remove", exact: true))
    |> click(by_role(:button, name: "Cancel", exact: true))

    :ok
  end

  step "I can continue editing its schedule", %{session: session} do
    session
    |> assert(visible(by_css("#schedule-form")))
    |> fill(opening_line(), "Still connected!")
    |> assert(visible(preview() |> filter(has_text: "Still connected!")))

    :ok
  end

  step "I ask to remove the place again and confirm", %{session: session} do
    session
    |> click(by_role(:button, name: "Remove", exact: true))
    |> click(by_role(:button, name: "Remove connection", exact: true))

    :ok
  end

  step "Social lists no connected places", %{session: session} do
    empty_list = by_css("#social-connections") |> filter(has_text: "Nothing connected yet")

    session
    |> assert(visible(empty_list))
    |> reload()
    |> assert(visible(empty_list))

    :ok
  end

  step "I choose morning-of posting with Space", %{session: session} do
    press(session, morning_of(), "Space")
    :ok
  end

  step "the social schedule choice stays focused and checked", %{session: session} do
    session
    |> assert(checked(morning_of()))
    |> assert(focused(morning_of()))
    |> assert(attribute(morning_of(), "aria-checked", "true"))

    :ok
  end

  step "I enter an opening line and finish immediately", %{session: session} do
    session
    |> fill(opening_line(), "See you tonight!")
    |> click(by_role(:button, name: "Done", exact: true))
    |> assert(count(by_role(by_css("#schedule-sheet"), :dialog), 0))

    :ok
  end

  step "reopening the social schedule shows both changes", %{session: session} do
    session
    |> click(edit())
    |> assert(checked(morning_of()))
    |> assert_has(preview() |> filter(has_text: "See you tonight!"))
    |> assert(css(sheet(), "opacity", "1"))
    |> press(opening_line(), "Tab")
    |> assert(focused(by_role(:button, name: "Remove", exact: true)))
    |> assert_browser("""
    Array.from(document.querySelectorAll('#schedule-form button, #schedule-form a')).every(control => {
      const bounds = control.getBoundingClientRect();
      return bounds.left >= 0 && bounds.right <= window.innerWidth;
    })
    """)

    :ok
  end

  step "I have returned to Social after connecting a place", %{session: session} = context do
    {session, group, place} = connected_place(session)
    schedule = schedule_dialog() |> filter(has_text: place.channel_name)

    session
    |> visit("/organize/#{group.slug}/social?connected=#{place.id}")
    |> assert(visible(schedule))
    |> reload()
    |> assert(visible(schedule))

    Map.put(context, :place, place)
  end

  step "I finish its schedule and open Members", %{session: session} do
    session
    |> click(by_role(:button, name: "Start posting", exact: true))
    |> assert_browser("location.search === ''")
    |> assert(count(schedule_dialog(), 0))
    |> click(by_role(:link, name: "Members", exact: true))
    |> assert(visible(by_role(:heading, name: "Members", level: 1)))

    :ok
  end

  step "Back returns to Social and back again reopens the connected place's schedule",
       %{session: session, place: place} do
    session
    |> Playwright.go_back()
    |> assert(attribute(by_role(:link, name: "Social", exact: true), "aria-current", "page"))
    |> assert(count(schedule_dialog(), 0))
    |> Playwright.go_back()
    |> assert(visible(schedule_dialog() |> filter(has_text: place.channel_name)))

    :ok
  end

  step "Forward returns to Social with the schedule closed", %{session: session} do
    session
    |> Playwright.go_forward()
    |> assert(count(schedule_dialog(), 0))
    |> assert(visible(by_role(:heading, name: "Social", level: 1)))

    :ok
  end

  defp connected_place(session) do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    place = generate(social_connection(group_id: group.id, actor: owner))
    {sign_in(session, owner), group, place}
  end

  defp edit, do: by_role(:button, name: "Edit", exact: true)
  defp preview, do: by_css("#social-post-preview")
  defp sheet, do: by_css("#schedule-sheet-container")
  defp schedule_dialog, do: by_role(by_css("#schedule-sheet"), :dialog)
  defp morning_of, do: by_role(:switch, name: "The morning of", exact: true)
  defp opening_line, do: by_label("Opening line", exact: true)
end
