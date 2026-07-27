defmodule IndividualNotificationReadSteps do
  use Cucumber.StepDefinition

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
end
