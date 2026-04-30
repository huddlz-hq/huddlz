defmodule HuddlzWeb.Api.Graphql.ChangeEmailTest do
  use HuddlzWeb.ApiCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications.DeliverWorker

  @mutation """
  mutation ChangeEmail($id: ID!, $email: String!, $currentPassword: String!) {
    changeEmail(id: $id, input: {email: $email, currentPassword: $currentPassword}) {
      result { id }
      errors { message }
    }
  }
  """

  describe "changeEmail mutation" do
    setup do
      user =
        generate(user_with_password(email: "before@example.com", password: "OldPassword123!"))

      {:ok, user: user}
    end

    test "actor changes their own email with the correct current password", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> authenticated_conn(user)
        |> gql_post(@mutation, %{
          "id" => user.id,
          "email" => "after@example.com",
          "currentPassword" => "OldPassword123!"
        })

      assert %{
               "data" => %{
                 "changeEmail" => %{
                   "result" => %{"id" => id},
                   "errors" => errors
                 }
               }
             } = json_response(conn, 200)

      assert errors == []
      assert id == user.id

      reloaded = Ash.get!(User, user.id, authorize?: false)
      assert to_string(reloaded.email) == "after@example.com"

      enqueued =
        all_enqueued(worker: DeliverWorker)
        |> Enum.filter(&(&1.args["trigger"] == "email_changed"))

      audiences = enqueued |> Enum.map(& &1.args["payload"]["audience"]) |> Enum.sort()
      assert audiences == ["new", "old"]

      assert Enum.all?(enqueued, &(&1.args["user_id"] == user.id))
      assert Enum.all?(enqueued, &(&1.args["payload"]["old_email"] == "before@example.com"))
    end

    test "wrong current password leaves the email untouched", %{conn: conn, user: user} do
      conn =
        conn
        |> authenticated_conn(user)
        |> gql_post(@mutation, %{
          "id" => user.id,
          "email" => "after@example.com",
          "currentPassword" => "WrongPassword"
        })

      body = json_response(conn, 200)

      assert get_in(body, ["data", "changeEmail", "result"]) == nil
      assert [_ | _] = body["data"]["changeEmail"]["errors"]

      reloaded = Ash.get!(User, user.id, authorize?: false)
      assert to_string(reloaded.email) == "before@example.com"

      refute_enqueued(worker: DeliverWorker, args: %{"trigger" => "email_changed"})
    end

    test "unauthenticated callers cannot change another user's email", %{
      conn: conn,
      user: user
    } do
      conn =
        gql_post(conn, @mutation, %{
          "id" => user.id,
          "email" => "after@example.com",
          "currentPassword" => "OldPassword123!"
        })

      body = json_response(conn, 200)

      assert get_in(body, ["data", "changeEmail", "result"]) == nil

      reloaded = Ash.get!(User, user.id, authorize?: false)
      assert to_string(reloaded.email) == "before@example.com"

      refute_enqueued(worker: DeliverWorker, args: %{"trigger" => "email_changed"})
    end
  end
end
