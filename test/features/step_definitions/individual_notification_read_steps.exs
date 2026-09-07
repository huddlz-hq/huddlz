defmodule IndividualNotificationReadSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Notifications

  step "I have an unread waitlist promotion notification for {string}",
       %{args: [huddl_title], current_user: user} = context do
    group = generate(group(owner_id: user.id, actor: user, is_public: true))

    huddl =
      generate(
        huddl(
          creator_id: user.id,
          actor: user,
          group_id: group.id,
          title: huddl_title
        )
      )

    {:ok, _job} =
      Notifications.deliver(user, :waitlist_promoted, %{
        "group_slug" => group.slug,
        "huddl_id" => huddl.id,
        "huddl_title" => huddl_title,
        "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at)
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
