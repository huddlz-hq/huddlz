defmodule UnsubscribeSteps do
  use Cucumber.StepDefinition

  import PhoenixTest
  import ExUnit.Assertions
  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications

  step "I visit the unsubscribe URL for trigger {string}",
       %{args: [trigger_str]} = context do
    user = context[:current_user] || raise "no current_user in context"
    trigger = String.to_existing_atom(trigger_str)
    token = Notifications.unsubscribe_token(user, trigger)

    session = context[:session] || context[:conn]
    session = visit(session, "/unsubscribe/#{token}")

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "the user {string} should have trigger {string} disabled",
       %{args: [email, trigger_str]} = context do
    [user] =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read!(authorize?: false)

    assert user.notification_preferences[trigger_str] == false,
           "expected #{email} to have #{trigger_str} disabled, got: " <>
             inspect(user.notification_preferences)

    {:ok, context}
  end
end
