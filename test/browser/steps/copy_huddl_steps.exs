defmodule BrowserCopyHuddlSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

  step "I opened a copied huddl on my phone", context do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    huddl = generate(huddl(group_id: group.id, actor: owner))

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/groups/#{group.slug}/huddlz/new?copy=#{huddl.id}")
      |> assert_has(".phx-connected")
      |> assert_has("h2", text: "Copied from")

    Map.put(context, :conn, conn)
  end

  step "I review the copied description", context do
    PhoenixTest.Playwright.evaluate(
      context.conn,
      "document.querySelector('#form_description').scrollIntoView({block: 'center'})",
      fn _ -> :ok end
    )

    context
  end

  step "I can reach Schedule huddl and Save as draft without scrolling", context do
    assert_browser(context.conn, """
    (() => ['publish-huddl', 'save-huddl-draft'].every(id => {
      const button = document.getElementById(id);
      const rect = button.getBoundingClientRect();
      return rect.top >= 0 && rect.bottom <= innerHeight && rect.left >= 0 &&
        rect.right <= innerWidth && rect.height >= 44 &&
        button.contains(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2));
    }))()
    """)

    context
  end
end
