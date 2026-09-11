defmodule BrowserSidebarScrollSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  @sidebar "document.querySelector('#mobile-navigation-drawer')"

  step "I have opened my agenda in a browser with enough groups to overflow the sidebar",
       context do
    member = generate(user(role: :user))

    for n <- 1..14 do
      generate(
        group(name: "Overflow group #{n}", owner_id: member.id, is_public: true, actor: member)
      )
    end

    conn =
      context.conn
      |> sign_in(member)
      |> visit("/agenda")
      |> assert_has(".phx-connected")
      |> assert_has(".sb-org-row", text: "Overflow group 14")

    Map.merge(context, %{conn: conn, member: member})
  end

  step "the sidebar is one scroll region", context do
    conn =
      assert_browser(context.conn, """
      (() => {
        const sidebar = #{@sidebar};
        const nav = sidebar.querySelector('.sb-nav');
        const scrolls = (el) => ['auto', 'scroll'].includes(getComputedStyle(el).overflowY);
        return sidebar.scrollHeight > sidebar.clientHeight + 40 && scrolls(sidebar) && !scrolls(nav);
      })()
      """)

    Map.put(context, :conn, conn)
  end

  step "I tab through to Sign out", context do
    # Nothing is focused on a fresh page, so the first Tab starts from the body.
    conn =
      Enum.reduce_while(1..60, press(context.conn, "body", "Tab"), fn _n, conn ->
        conn = press(conn, ":focus", "Tab")

        if evaluate(conn, "document.activeElement.id === 'sign-out-link'"),
          do: {:halt, conn},
          else: {:cont, conn}
      end)

    Map.put(context, :conn, assert_has(conn, "#sign-out-link:focus"))
  end

  step "Sign out is scrolled into view", context do
    conn =
      assert_browser(context.conn, """
      (() => {
        const sidebar = #{@sidebar};
        const box = sidebar.getBoundingClientRect();
        const link = document.querySelector('#sign-out-link').getBoundingClientRect();
        return sidebar.scrollTop > 0 && link.top >= box.top && link.bottom <= box.bottom;
      })()
      """)

    Map.put(context, :conn, conn)
  end

  step "I scroll the lower sidebar back to the top", context do
    # Scrolling over the account area moves the same region as scrolling
    # over the navigation: there is only one.
    assert evaluate(context.conn, """
           (() => {
             const sidebar = #{@sidebar};
             const account = sidebar.querySelector('.sb-account');
             sidebar.scrollTop = account.getBoundingClientRect().top - sidebar.getBoundingClientRect().top + sidebar.scrollTop;
             sidebar.scrollTop = 0;
             return sidebar.scrollTop === 0;
           })()
           """)

    context
  end

  step "the top navigation is in view and the account area has scrolled away", context do
    conn =
      assert_browser(context.conn, """
      (() => {
        const sidebar = #{@sidebar};
        const box = sidebar.getBoundingClientRect();
        const discover = sidebar.querySelector('.sb-item').getBoundingClientRect();
        const user = document.querySelector('#sidebar-user').getBoundingClientRect();
        return discover.top >= box.top && discover.bottom <= box.bottom && user.top > box.bottom;
      })()
      """)

    Map.put(context, :conn, conn)
  end

  step "the page behind the sidebar is still usable", context do
    conn =
      context.conn
      |> assert_has("main h1", text: "Agenda")
      |> assert_browser(
        "!document.querySelector('main').inert && document.querySelector('main').getBoundingClientRect().left > 0"
      )

    Map.put(context, :conn, conn)
  end

  defp evaluate(conn, expression) do
    {:ok, value} =
      PlaywrightEx.Frame.evaluate(conn.frame_id, expression: expression, timeout: 5_000)

    value
  end
end
