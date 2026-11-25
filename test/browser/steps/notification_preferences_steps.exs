defmodule BrowserNotificationPreferencesSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 2, step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  step "I have opened my notification preferences in a browser", %{session: session} do
    member = generate(user(role: :user))

    session
    |> sign_in(member)
    |> visit("/profile/notifications")
    |> assert(visible(by_role(:heading, level: 1, name: "Notifications")))

    %{member: member}
  end

  step "my account has been removed underneath the page", context do
    Huddlz.Repo.delete!(context.member)
    :ok
  end

  # A person flips a switch by clicking its row label; the checkbox itself
  # is visually hidden behind the track.
  step "I flip {string} off", %{args: [label], session: session} do
    click(session, by_css("label") |> filter(has: by_text(label)))
    :ok
  end

  step "the row says the change could not be saved", %{session: session} do
    assert(session, visible(by_role(:alert) |> filter(has_text: "Couldn't save")))
    :ok
  end

  step "{string} is shown as on", %{args: [label], session: session} do
    switch = by_role(:switch, name: label, exact: true)

    session
    |> assert(checked(switch))
    |> assert(attribute(switch, "aria-checked", "true"))

    :ok
  end

  step "the preference switch keeps keyboard focus", %{session: session} do
    assert(session, attached(by_css("[role='switch']:focus")))
    :ok
  end
end
