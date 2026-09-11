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

  step "the brand and account rows keep their height", context do
    conn =
      assert_browser(context.conn, """
      (() => {
        const brand = document.querySelector('#mobile-navigation-drawer .sidebar-brand').getBoundingClientRect().height;
        const user = document.querySelector('#sidebar-user').getBoundingClientRect().height;
        return Math.round(brand) === 64 && user >= 60;
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

  # Real wheel events, so an intercepted wheel or a second scroll container
  # would fail here where setting scrollTop from a script would not.
  step "I scroll up with the wheel over the account area", context do
    Map.put(context, :conn, wheel_over(context.conn, "#sidebar-user", -2000))
  end

  step "I scroll down with the wheel over the top navigation", context do
    Map.put(context, :conn, wheel_over(context.conn, "#mobile-navigation-drawer .sb-item", 2000))
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

  step "the page behind the sidebar has not moved and is still usable", context do
    conn =
      context.conn
      |> assert_has("main h1", text: "Agenda")
      |> assert_browser("""
      window.scrollY === 0 && !document.querySelector('main').inert &&
        document.querySelector('main').getBoundingClientRect().left > 0
      """)

    Map.put(context, :conn, conn)
  end

  defp wheel_over(conn, selector, delta_y) do
    %{"x" => x, "y" => y} =
      evaluate(conn, """
      (() => {
        const r = document.querySelector(#{inspect(selector)}).getBoundingClientRect();
        return {x: r.left + r.width / 2, y: r.top + r.height / 2};
      })()
      """)

    {:ok, _} = PlaywrightEx.Page.mouse_move(conn.page_id, x: x, y: y, timeout: 5_000)

    # The wheel call answers with an empty result; the next step observes the effect.
    %{id: _} =
      PlaywrightEx.send(
        %{guid: conn.page_id, method: :mouse_wheel, params: %{delta_x: 0, delta_y: delta_y}},
        timeout: 5_000
      )

    conn
  end

  defp evaluate(conn, expression) do
    {:ok, value} =
      PlaywrightEx.Frame.evaluate(conn.frame_id, expression: expression, timeout: 5_000)

    value
  end
end
