defmodule NotificationPreferenceValidationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [json_response: 2]

  step "I have opted out of RSVP confirmations through the API", context do
    user = generate(user())
    preferences = %{"rsvp_confirmation" => false}
    response = update_preferences(context.conn, user, preferences)
    assert %{"errors" => []} = response["data"]["updateNotificationPreferences"]

    Map.merge(context, %{preference_user: user, saved_preferences: preferences})
  end

  step "I request these notification preferences through the API:", context do
    preferences =
      Map.new(context.datatable.maps, fn row ->
        {row["preference"], Jason.decode!(row["value"])}
      end)

    response = update_preferences(context.conn, context.preference_user, preferences)
    Map.put(context, :preference_response, response)
  end

  step "the notification preference update should be rejected", context do
    assert %{"result" => nil, "errors" => [%{"fields" => ["preferences"]}]} =
             context.preference_response["data"]["updateNotificationPreferences"]

    context
  end

  step "my saved notification preferences should be unchanged", context do
    response =
      context.conn
      |> authenticated_conn(context.preference_user)
      |> gql_post("query { me { notificationPreferences } }", %{})
      |> json_response(200)

    assert Jason.decode!(response["data"]["me"]["notificationPreferences"]) ==
             context.saved_preferences

    context
  end

  defp update_preferences(conn, user, preferences) do
    query = """
    mutation UpdatePreferences($id: ID!, $preferences: JsonString!) {
      updateNotificationPreferences(id: $id, input: {preferences: $preferences}) {
        result { id }
        errors { fields }
      }
    }
    """

    conn
    |> authenticated_conn(user)
    |> gql_post(query, %{"id" => user.id, "preferences" => Jason.encode!(preferences)})
    |> json_response(200)
  end
end
