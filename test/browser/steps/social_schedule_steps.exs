defmodule BrowserSocialScheduleSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [evaluate: 2, press: 3]

  step "I am editing a social connection as its owner", context do
    {conn, group, _place} = connected_place(context.conn)

    conn =
      conn
      |> visit("/organize/#{group.slug}/social")
      |> assert_has("body .phx-connected")
      |> click_button("Edit")
      |> assert_has("#social-post-preview", text: "Morning-of post preview")
      # The sheet moves focus to its first control again two animation
      # frames after mounting; wait for it to finish opening before typing.
      |> assert_browser(
        "getComputedStyle(document.querySelector('#schedule-sheet-container')).opacity === '1'"
      )

    Map.put(context, :conn, conn)
  end

  step "I ask to remove the place and cancel", context do
    conn = context.conn |> click_button("Remove") |> click_button("Cancel")
    Map.put(context, :conn, conn)
  end

  step "I can continue editing its schedule", context do
    conn =
      context.conn
      |> assert_has("#schedule-form")
      |> fill_in("Opening line", with: "Still connected!")
      |> assert_has("#social-post-preview", text: "Still connected!")

    Map.put(context, :conn, conn)
  end

  step "I ask to remove the place again and confirm", context do
    conn = context.conn |> click_button("Remove") |> click_button("Remove connection")
    Map.put(context, :conn, conn)
  end

  step "Social lists no connected places", context do
    context.conn
    |> assert_has("#social-connections", text: "Nothing connected yet")
    |> reload_page()
    |> assert_has("#social-connections", text: "Nothing connected yet")

    context
  end

  step "I choose morning-of posting with Space", context do
    conn = press(context.conn, "#moments_morning_of", "Space")
    Map.put(context, :conn, conn)
  end

  step "the social schedule choice stays focused and checked", context do
    assert_has(context.conn, "#moments_morning_of:checked:focus[aria-checked='true']")
    context
  end

  step "I enter an opening line and finish immediately", context do
    conn =
      context.conn
      |> fill_in("Opening line", with: "See you tonight!")
      |> click_button("Done")
      |> refute_has("#schedule-sheet")

    Map.put(context, :conn, conn)
  end

  step "reopening the social schedule shows both changes", context do
    conn =
      context.conn
      |> click_button("Edit")
      |> assert_has("#moments_morning_of:checked")
      |> assert_has("#social-post-preview", text: "See you tonight!")
      |> assert_browser(
        "getComputedStyle(document.querySelector('#schedule-sheet-container')).opacity === '1'"
      )
      |> press("#opening-line", "Tab")
      |> assert_has("#remove-connection:focus")
      |> assert_browser("""
      Array.from(document.querySelectorAll('#schedule-form button, #schedule-form a')).every(control => {
        const bounds = control.getBoundingClientRect();
        return bounds.left >= 0 && bounds.right <= window.innerWidth;
      })
      """)

    Map.put(context, :conn, conn)
  end

  step "I have returned to Social after connecting a place", context do
    {conn, group, place} = connected_place(context.conn)

    conn =
      conn
      |> visit("/organize/#{group.slug}/social?connected=#{place.id}")
      |> assert_has("#schedule-sheet", text: place.channel_name)
      |> reload_page()
      |> assert_has("body .phx-connected")
      |> assert_has("#schedule-sheet", text: place.channel_name)

    Map.merge(context, %{conn: conn, place: place})
  end

  step "I finish its schedule and open Members", context do
    conn =
      context.conn
      |> click_button("Start posting")
      |> assert_browser("location.search === ''")
      |> refute_has("#schedule-sheet")
      |> click_link("Members")
      |> assert_has("h1", text: "Members")

    Map.put(context, :conn, conn)
  end

  step "Back returns to Social and back again reopens the connected place's schedule", context do
    conn =
      context.conn
      |> evaluate("requestAnimationFrame(() => history.back())")
      |> assert_has("a[aria-current='page']", text: "Social")
      |> refute_has("#schedule-sheet")
      |> evaluate("requestAnimationFrame(() => history.back())")
      |> assert_has("#schedule-sheet", text: context.place.channel_name)

    Map.put(context, :conn, conn)
  end

  step "Forward returns to Social with the schedule closed", context do
    context.conn
    |> evaluate("requestAnimationFrame(() => history.forward())")
    |> refute_has("#schedule-sheet")
    |> assert_has("h1", text: "Social")

    context
  end

  defp connected_place(conn) do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    place = generate(social_connection(group_id: group.id, actor: owner))
    {sign_in(conn, owner), group, place}
  end
end
