defmodule HuddlzWeb.Api.Graphql.NotificationPreferencesTest do
  use HuddlzWeb.ApiCase, async: true

  alias Huddlz.Accounts.User

  describe "me query notificationPreferences field" do
    test "returns the actor's saved preferences", %{conn: conn} do
      target = generate(user())

      target
      |> Ash.Changeset.for_update(
        :update_notification_preferences,
        %{preferences: %{"rsvp_received" => false}},
        actor: target
      )
      |> Ash.update!()

      query = """
      query Me {
        me { id notificationPreferences }
      }
      """

      conn =
        conn
        |> authenticated_conn(target)
        |> gql_post(query, %{})

      assert %{"data" => %{"me" => %{"id" => id, "notificationPreferences" => prefs_json}}} =
               json_response(conn, 200)

      assert id == target.id
      assert Jason.decode!(prefs_json) == %{"rsvp_received" => false}
    end

    test "unauthenticated callers get nil", %{conn: conn} do
      query = """
      query Me {
        me { id notificationPreferences }
      }
      """

      conn = gql_post(conn, query, %{})

      assert %{"data" => %{"me" => nil}} = json_response(conn, 200)
    end
  end

  describe "updateNotificationPreferences mutation" do
    test "actor flips their own preference to false", %{conn: conn} do
      target = generate(user())

      query = """
      mutation Toggle($prefs: JsonString!) {
        updateNotificationPreferences(id: "#{target.id}", input: {preferences: $prefs}) {
          result { id }
          errors { message }
        }
      }
      """

      conn =
        conn
        |> authenticated_conn(target)
        |> gql_post(query, %{"prefs" => Jason.encode!(%{"rsvp_received" => false})})

      assert %{
               "data" => %{
                 "updateNotificationPreferences" => %{
                   "result" => %{"id" => id},
                   "errors" => errors
                 }
               }
             } = json_response(conn, 200)

      assert errors in [nil, []]
      assert id == target.id

      reloaded = Ash.get!(User, target.id, authorize?: false)
      assert reloaded.notification_preferences["rsvp_received"] == false
    end

    test "rejects unauthenticated callers", %{conn: conn} do
      target = generate(user())

      query = """
      mutation Toggle($prefs: JsonString!) {
        updateNotificationPreferences(id: "#{target.id}", input: {preferences: $prefs}) {
          result { id }
          errors { message }
        }
      }
      """

      conn = gql_post(conn, query, %{"prefs" => Jason.encode!(%{"rsvp_received" => false})})

      body = json_response(conn, 200)

      assert get_in(body, ["data", "updateNotificationPreferences", "result"]) == nil

      reloaded = Ash.get!(User, target.id, authorize?: false)
      assert reloaded.notification_preferences == %{}
    end

    test "forbids actor from updating a different user's preferences", %{conn: conn} do
      target = generate(user())
      other = generate(user())

      query = """
      mutation Toggle($prefs: JsonString!) {
        updateNotificationPreferences(id: "#{other.id}", input: {preferences: $prefs}) {
          result { id }
          errors { message }
        }
      }
      """

      conn =
        conn
        |> authenticated_conn(target)
        |> gql_post(query, %{"prefs" => Jason.encode!(%{"rsvp_received" => false})})

      body = json_response(conn, 200)

      assert get_in(body, ["data", "updateNotificationPreferences", "result"]) == nil

      reloaded = Ash.get!(User, other.id, authorize?: false)
      assert reloaded.notification_preferences == %{}
    end
  end
end
