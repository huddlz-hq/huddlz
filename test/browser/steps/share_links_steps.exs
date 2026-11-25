defmodule BrowserShareLinksSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator

  step "I am viewing a public {string} to share", %{args: [page], session: session} do
    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
    path = page_path(page, group, owner)
    visit(session, path)

    # Retain real clipboard access for observation even when the app's API is unavailable.
    Fluffy.Playwright.evaluate(session, """
    window.readClipboard = navigator.clipboard.readText.bind(navigator.clipboard);
    navigator.clipboard.writeText('previous clipboard contents');
    """)

    %{share_url: HuddlzWeb.Endpoint.url() <> path}
  end

  step "direct clipboard access is {string}", %{args: [availability], session: session} do
    Fluffy.Playwright.evaluate(session, clipboard_availability(availability))
    :ok
  end

  step "I copy the address from the Share section", %{session: session} do
    session
    |> assert(count(by_role(:dialog), 0))
    |> click(by_role(share_actions(), :button, name: "Copy link"))

    :ok
  end

  step "my clipboard contains the page's address", %{session: session} = context do
    assert Fluffy.Playwright.evaluate(session, "window.readClipboard()") == context.share_url
    :ok
  end

  step "the Share section confirms the address was copied", %{session: session} do
    session
    |> assert(visible(share_actions() |> filter(has_text: "Copied!")))
    |> assert(focused(by_role(share_actions(), :button, name: "Copied!")))

    :ok
  end

  step "I copy the address from the QR code dialog", %{session: session} do
    session
    |> click(by_role(share_actions(), :button, name: "QR code"))
    |> click(by_role(by_role(:dialog), :button, name: "Copy link"))

    :ok
  end

  step "the QR code dialog confirms the address was copied", %{session: session} do
    session
    |> assert(visible(by_role(:dialog) |> filter(has_text: "Copied!")))
    |> assert(focused(by_role(by_role(:dialog), :button, name: "Copied!")))

    :ok
  end

  defp share_actions, do: by_css("#share-actions")

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
