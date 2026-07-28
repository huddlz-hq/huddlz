defmodule IndividualNotificationReadSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  alias Huddlz.Notifications

  step "I have an unread waitlist promotion notification for {string}",
       %{args: [huddl_title]} = context do
    {:ok, _job} =
      Notifications.deliver(context.current_user, :waitlist_promoted, %{
        "group_slug" => "elixir-picnic",
        "huddl_id" => "00000000-0000-0000-0000-000000000000",
        "huddl_title" => huddl_title,
        "starts_at_iso" => "2026-08-01T16:00:00Z"
      })

    context
  end

  step "persistent navigation should show one unread notification", context do
    session = context[:session] || context[:conn]

    assert_has(
      session,
      ~s|#notification-nav-link[aria-label="Notifications, 1 unread"]|
    )

    assert_has(session, "#notification-nav-badge", text: "1")
    context
  end

  step "persistent navigation should show no unread notifications", context do
    session = context[:session] || context[:conn]

    assert_has(session, ~s|#notification-nav-link[aria-label="Notifications"]|)
    refute_has(session, "#notification-nav-badge")
    context
  end
end
