defmodule BrowserCopyHuddlSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  step "I opened a copied huddl on my phone", %{session: session} do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    huddl = generate(huddl(group_id: group.id, actor: owner))

    session
    |> sign_in(owner)
    |> visit("/groups/#{group.slug}/huddlz/new?copy=#{huddl.id}")
    |> assert(visible(by_role(:heading, level: 2, name: "Copied from")))

    :ok
  end

  step "I review the copied description", %{session: session} do
    Fluffy.Playwright.evaluate(
      session,
      by_label("Description", exact: true),
      "field => field.scrollIntoView({block: 'center'})"
    )

    :ok
  end

  step "I can reach Schedule huddl and Save as draft without scrolling", %{session: session} do
    assert_browser(session, """
    (() => ['publish-huddl', 'save-huddl-draft'].every(id => {
      const button = document.getElementById(id);
      const rect = button.getBoundingClientRect();
      return rect.top >= 0 && rect.bottom <= innerHeight && rect.left >= 0 &&
        rect.right <= innerWidth && rect.height >= 44 &&
        button.contains(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2));
    }))()
    """)

    :ok
  end
end
