defmodule BrowserSocialScheduleSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  step "I am editing a social connection as its owner", context do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    generate(social_connection(group_id: group.id, actor: owner))

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/organize/#{group.slug}/social")
      |> click_button("Edit")
      |> assert_has("#social-post-preview", text: "Morning-of post preview")

    Map.put(context, :conn, conn)
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
end
