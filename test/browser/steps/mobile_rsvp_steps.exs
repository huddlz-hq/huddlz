defmodule BrowserMobileRsvpSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

  step "I am viewing an upcoming huddl in a narrow browser", context do
    owner = generate(user(display_name: "Sam Rivera"))
    member = generate(user(display_name: "Ada Park"))
    group = generate(group(owner_id: owner.id, actor: owner))
    generate(group_member(group_id: group.id, user_id: member.id, role: :member))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          is_private: false,
          description: String.duplicate("Bring a laptop and questions. ", 40),
          actor: owner
        )
      )

    conn =
      context.conn
      |> sign_in(member)
      |> visit("/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> assert_has(".phx-connected")

    Map.merge(context, %{conn: conn, huddl: huddl})
  end

  step "the RSVP button is docked to the bottom edge before I scroll", context do
    assert_browser(context.conn, """
    (() => {
      const dock = document.querySelector('.rsvp-state[data-dock]');
      if (!dock) return false;
      const rect = dock.getBoundingClientRect();
      const button = dock.querySelector('.rsvp-cta').getBoundingClientRect();
      return Math.abs(rect.bottom - innerHeight) < 1 &&
        button.top >= rect.top && button.bottom <= rect.bottom &&
        document.documentElement.scrollWidth <= innerWidth;
    })()
    """)

    context
  end

  step "I scroll to the end of the page", context do
    assert_browser(context.conn, """
    (() => {
      window.scrollTo(0, document.documentElement.scrollHeight);
      return window.scrollY > 0;
    })()
    """)

    context
  end

  step "the dock still sits on the bottom edge and covers nothing", context do
    assert_browser(context.conn, """
    (() => {
      const dock = document.querySelector('.rsvp-state[data-dock]').getBoundingClientRect();
      const last = document.querySelector('#huddl-group').getBoundingClientRect();
      return Math.abs(dock.bottom - innerHeight) < 1 && last.bottom <= dock.top;
    })()
    """)

    context
  end

  step "I RSVP from the dock", context do
    Map.put(
      context,
      :conn,
      click_button(context.conn, ".rsvp-state[data-dock]", "RSVP to this huddl")
    )
  end

  step "the dock shows I am attending and offers to cancel", context do
    conn =
      context.conn
      |> assert_has(".rsvp-state[data-dock] .rsvp-banner.cyan", text: "You're attending")
      |> assert_has(".rsvp-state[data-dock] button", text: "Cancel RSVP")

    assert_browser(conn, """
    (() => {
      const dock = document.querySelector('.rsvp-state[data-dock]').getBoundingClientRect();
      return Math.abs(dock.bottom - innerHeight) < 1 && document.documentElement.scrollWidth <= innerWidth;
    })()
    """)

    Map.put(context, :conn, conn)
  end
end
