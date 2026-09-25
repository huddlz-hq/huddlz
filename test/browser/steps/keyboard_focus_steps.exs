defmodule BrowserKeyboardFocusSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  step "I am signed in and looking at my groups in a browser", context do
    member = generate(user(role: :user))
    conn = context.conn |> sign_in(member) |> visit("/groups") |> assert_has(".phx-connected")
    Map.put(context, :conn, conn)
  end

  step "I open {string} in a browser", %{args: [page]} = context do
    open_page(context, page)
  end

  step "I press Tab from the top of the page", context do
    Map.put(context, :conn, press(context.conn, "body", "Tab"))
  end

  step "I press Tab", context do
    Map.put(context, :conn, press(context.conn, ":focus", "Tab"))
  end

  step "I follow the skip link with Enter", context do
    Map.put(context, :conn, press(context.conn, ":focus", "Enter"))
  end

  step "{string} has keyboard focus", %{args: [name]} = context do
    assert_focused(context.conn, name)
    context
  end

  step "keyboard focus is in the page content", context do
    assert_browser(context.conn, "document.activeElement.id === 'main-content'")
    context
  end

  step "keyboard focus is still in the page content", context do
    assert_browser(context.conn, """
    document.activeElement !== document.getElementById('main-content') &&
      document.getElementById('main-content').contains(document.activeElement)
    """)

    context
  end

  defp open_page(context, "the home page"), do: visit_signed_out(context, "/")
  defp open_page(context, "sign in"), do: visit_signed_out(context, "/sign-in")
  defp open_page(context, "discover"), do: visit_signed_out(context, "/discover")

  defp visit_signed_out(context, path) do
    Map.put(context, :conn, context.conn |> visit(path) |> assert_has(".phx-connected"))
  end

  defp assert_focused(conn, name) do
    assert_browser(conn, """
    (() => {
      const field = document.activeElement;
      return #{label_matches("field")} === #{Jason.encode!(name)};
    })()
    """)
  end

  # The accessible name the step reads: a control's label, else its
  # aria-label, else its own text.
  defp label_matches(var) do
    """
    ((#{var}.labels && #{var}.labels[0]?.textContent) ||
      #{var}.getAttribute('aria-label') || #{var}.textContent || '').replace(/\\s+/g, ' ').trim()
    """
  end
end
