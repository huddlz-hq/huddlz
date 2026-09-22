defmodule BrowserShareLinksSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  step "I am viewing a public {string} to share", %{args: [page]} = context do
    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
    path = page_path(page, group, owner)
    conn = context.conn |> visit(path) |> assert_has(".phx-connected")

    # Retain real clipboard access for observation even when the app's API is unavailable.
    assert {:ok, _} =
             PlaywrightEx.Frame.evaluate(conn.frame_id,
               expression: """
               window.readClipboard = navigator.clipboard.readText.bind(navigator.clipboard);
               navigator.clipboard.writeText('previous clipboard contents');
               """,
               timeout: 5_000
             )

    Map.merge(context, %{conn: conn, share_url: HuddlzWeb.Endpoint.url() <> path})
  end

  step "direct clipboard access is {string}", %{args: [availability]} = context do
    assert {:ok, _} =
             PlaywrightEx.Frame.evaluate(context.conn.frame_id,
               expression: clipboard_availability(availability),
               timeout: 5_000
             )

    context
  end

  step "I copy the address from the Share section", context do
    refute_has(context.conn, "[role='dialog']")
    Map.put(context, :conn, click_button(context.conn, "#share-actions", "Copy link"))
  end

  step "my clipboard contains the page's address", context do
    assert {:ok, copied} =
             PlaywrightEx.Frame.evaluate(context.conn.frame_id,
               expression: "window.readClipboard()",
               timeout: 5_000
             )

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
      |> click_button("#share-actions", "QR code")
      |> click_button("[role='dialog']", "Copy link")

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
    navigator.clipboard.writeText = () => Promise.reject(new DOMException('Denied', 'NotAllowedError'));
    """

  defp clipboard_availability("available"), do: "true"
end
