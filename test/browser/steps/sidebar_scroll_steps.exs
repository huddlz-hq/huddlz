defmodule BrowserSidebarScrollSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Fluffy.Playwright.Keyboard
  alias Fluffy.Playwright.Mouse

  @sidebar "document.querySelector('#mobile-navigation-drawer')"

  step "I have opened my agenda in a browser with enough groups to overflow the sidebar",
       %{session: session} do
    member = generate(user(role: :user))

    for n <- 1..14 do
      generate(
        group(name: "Overflow group #{n}", owner_id: member.id, is_public: true, actor: member)
      )
    end

    session
    |> sign_in(member)
    |> visit("/agenda")
    |> assert_has(by_css(".sb-org-row") |> filter(has_text: "Overflow group 14"))

    %{member: member}
  end

  step "the sidebar is one scroll region", %{session: session} do
    assert_browser(session, """
    (() => {
      const sidebar = #{@sidebar};
      const nav = sidebar.querySelector('.sb-nav');
      const scrolls = (el) => ['auto', 'scroll'].includes(getComputedStyle(el).overflowY);
      return sidebar.scrollHeight > sidebar.clientHeight + 40 && scrolls(sidebar) && !scrolls(nav);
    })()
    """)

    :ok
  end

  step "the brand and account rows keep their height", %{session: session} do
    assert_browser(session, """
    (() => {
      const brand = document.querySelector('#mobile-navigation-drawer .sidebar-brand').getBoundingClientRect().height;
      const user = document.querySelector('#sidebar-user').getBoundingClientRect().height;
      return Math.round(brand) === 64 && user >= 60;
    })()
    """)

    :ok
  end

  step "I tab through to Sign out", %{session: session} do
    # Nothing is focused on a fresh page, so the first Tab starts from the body.
    press(session, by_css("body"), "Tab")

    Enum.find(1..60, fn _n ->
      session
      |> Keyboard.press("Tab")
      |> get_attribute(by_css(":focus"), "id") == "sign-out-link"
    end)

    assert(session, focused(by_css("#sign-out-link")))
    :ok
  end

  step "Sign out is scrolled into view", %{session: session} do
    assert_browser(session, """
    (() => {
      const sidebar = #{@sidebar};
      const box = sidebar.getBoundingClientRect();
      const link = document.querySelector('#sign-out-link').getBoundingClientRect();
      return sidebar.scrollTop > 0 && link.top >= box.top && link.bottom <= box.bottom;
    })()
    """)

    :ok
  end

  # Real wheel events, so an intercepted wheel or a second scroll container
  # would fail here where setting scrollTop from a script would not.
  step "I scroll up with the wheel over the account area", %{session: session} do
    wheel_over(session, by_css("#sidebar-user"), -2000)
    :ok
  end

  step "I scroll down with the wheel over the top navigation", %{session: session} do
    wheel_over(session, by_css("#mobile-navigation-drawer .sb-item") |> first(), 2000)
    :ok
  end

  step "the top navigation is in view and the account area has scrolled away",
       %{session: session} do
    assert_browser(session, """
    (() => {
      const sidebar = #{@sidebar};
      const box = sidebar.getBoundingClientRect();
      const discover = sidebar.querySelector('.sb-item').getBoundingClientRect();
      const user = document.querySelector('#sidebar-user').getBoundingClientRect();
      return discover.top >= box.top && discover.bottom <= box.bottom && user.top > box.bottom;
    })()
    """)

    :ok
  end

  step "the page behind the sidebar has not moved and is still usable", %{session: session} do
    session
    |> assert_has(by_role(by_css("main"), :heading, level: 1, name: "Agenda"))
    |> assert_browser("""
    window.scrollY === 0 && !document.querySelector('main').inert &&
      document.querySelector('main').getBoundingClientRect().left > 0
    """)

    :ok
  end

  # The pointer goes to the middle of the element's on-screen part: an element
  # partly below the fold has its centre off the page, where a wheel reaches
  # nothing.
  defp wheel_over(session, locator, delta_y) do
    box = Fluffy.Playwright.bounding_box(session, locator)
    %{height: height} = Fluffy.Playwright.viewport_size(session)
    top = max(box.y, 0)
    bottom = min(box.y + box.height, height)

    session
    |> Mouse.move(box.x + box.width / 2, (top + bottom) / 2)
    |> Mouse.wheel(0, delta_y)
  end
end
