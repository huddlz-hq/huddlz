defmodule BrowserMobileRsvpSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 2, step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  step "I am viewing an upcoming huddl in a narrow browser", %{session: session} do
    owner = generate(user(display_name: "Sam Rivera"))
    member = generate(user(display_name: "Ada Park"))
    group = generate(group(owner_id: owner.id, actor: owner))
    generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

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

    session
    |> sign_in(member)
    |> visit("/groups/#{group.slug}/huddlz/#{huddl.id}")

    %{huddl: huddl}
  end

  step "the RSVP button is docked to the bottom edge before I scroll", %{session: session} do
    assert_browser(session, """
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

    :ok
  end

  step "I scroll to the end of the page", %{session: session} do
    assert_browser(session, """
    (() => {
      window.scrollTo(0, document.documentElement.scrollHeight);
      return window.scrollY > 0;
    })()
    """)

    :ok
  end

  step "the dock still sits on the bottom edge and covers nothing", %{session: session} do
    assert_browser(session, """
    (() => {
      const dock = document.querySelector('.rsvp-state[data-dock]').getBoundingClientRect();
      const last = document.querySelector('#huddl-group').getBoundingClientRect();
      return Math.abs(dock.bottom - innerHeight) < 1 && last.bottom <= dock.top;
    })()
    """)

    :ok
  end

  step "I RSVP from the dock", %{session: session} do
    click(session, by_role(dock(), :button, name: "RSVP to this huddl"))
    :ok
  end

  step "the dock shows I am attending and offers to cancel", %{session: session} do
    session
    |> assert(
      visible(by_css(dock(), ".rsvp-banner.cyan") |> filter(has_text: "You're attending"))
    )
    |> assert(visible(by_role(dock(), :button, name: "Cancel RSVP")))
    |> assert_browser("""
    (() => {
      const dock = document.querySelector('.rsvp-state[data-dock]').getBoundingClientRect();
      return Math.abs(dock.bottom - innerHeight) < 1 && document.documentElement.scrollWidth <= innerWidth;
    })()
    """)

    :ok
  end

  defp dock, do: by_css(".rsvp-state[data-dock]")
end
