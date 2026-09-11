defmodule BrowserNotificationPreferencesSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [click: 3]

  step "I have opened my notification preferences in a browser", context do
    member = generate(user(role: :user))

    conn =
      context.conn
      |> sign_in(member)
      |> visit("/profile/notifications")
      |> assert_has(".phx-connected")
      |> assert_has("h1", text: "Notifications")

    Map.merge(context, %{conn: conn, member: member})
  end

  step "my account has been removed underneath the page", context do
    Huddlz.Repo.delete!(context.member)
    context
  end

  # A person flips a switch by clicking its row label; the checkbox itself
  # is visually hidden behind the track.
  step "I flip {string} off", %{args: [label]} = context do
    Map.put(context, :conn, click(context.conn, "label", label))
  end

  step "the row says the change could not be saved", context do
    Map.put(context, :conn, assert_has(context.conn, "[role=alert]", text: "Couldn't save"))
  end

  step "{string} is shown as on", %{args: [label]} = context do
    conn =
      assert_browser(context.conn, """
      (() => {
        const label = [...document.querySelectorAll('label')]
          .find((l) => l.textContent.trim() === #{Jason.encode!(label)});
        const input = label && document.getElementById(label.htmlFor);
        return !!input && input.checked && input.getAttribute('aria-checked') === 'true';
      })()
      """)

    Map.put(context, :conn, conn)
  end

  step "the preference switch keeps keyboard focus", context do
    conn =
      assert_browser(context.conn, "document.activeElement?.getAttribute('role') === 'switch'")

    Map.put(context, :conn, conn)
  end
end
