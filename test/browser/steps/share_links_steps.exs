defmodule BrowserShareLinksSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Fluffy.PhoenixTest

  step "I am viewing a public {string} to share", %{args: [page]} = context do
    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
    path = page_path(page, group, owner)
    conn = context.conn |> visit(path)

    # Retain real clipboard access for observation even when the app's API is unavailable.
    unwrap(
      conn,
      &Playwright.Page.evaluate!(&1, """
      window.readClipboard = navigator.clipboard.readText.bind(navigator.clipboard);
      navigator.clipboard.writeText('previous clipboard contents');
      """)
    )

    Map.merge(context, %{conn: conn, share_url: HuddlzWeb.Endpoint.url() <> path})
  end

  step "direct clipboard access is {string}", %{args: [availability]} = context do
    unwrap(context.conn, &Playwright.Page.evaluate!(&1, clipboard_availability(availability)))

    context
  end

  step "I copy the address from the Share section", context do
    refute_has(context.conn, "[role='dialog']")
    Map.put(context, :conn, click_button(context.conn, "#share-actions button", "Copy link"))
  end

  step "my clipboard contains the page's address", context do
    copied =
      unwrap_and_return(context.conn, &Playwright.Page.evaluate!(&1, "window.readClipboard()"))

    assert copied == context.share_url

    context
  end

  step "the Share section confirms the address was copied", context do
    conn =
      context.conn
      |> assert_has("#share-actions", text: "Copied!")
      |> assert_has("#share-actions button:focus", text: "Copied!")

    Map.put(context, :conn, conn)
  end

  step "I copy the address from the QR code dialog", context do
    conn =
      context.conn
      |> click_button("#share-actions button", "QR code")
      |> click_button("[role='dialog'] button", "Copy link")

    Map.put(context, :conn, conn)
  end

  step "the QR code dialog confirms the address was copied", context do
    conn =
      context.conn
      |> assert_has("[role='dialog']", text: "Copied!")
      |> assert_has("[role='dialog'] button:focus", text: "Copied!")

    Map.put(context, :conn, conn)
  end

  defp page_path("group", group, _owner), do: "/groups/#{group.slug}"

  defp page_path("huddl", group, owner) do
    huddl =
      generate(huddl(group_id: group.id, creator_id: owner.id, is_private: false, actor: owner))

    "/groups/#{group.slug}/huddlz/#{huddl.id}"
  end

  defp clipboard_availability("unavailable"),
    do: "Object.defineProperty(navigator, 'clipboard', {value: undefined, configurable: true})"

  defp clipboard_availability("rejected"),
    do: """
    () => {
      navigator.clipboard.writeText = () => Promise.reject(new DOMException('Denied', 'NotAllowedError'));
    }
    """

  defp clipboard_availability("available"), do: "true"
end
