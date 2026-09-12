defmodule HuddlzWeb.Api.Graphql.ChangeEmailTest do
  use HuddlzWeb.ApiCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Accounts.EmailChangeDelivery
  alias Huddlz.Accounts.User

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

    test "actor requests a pending change with the correct current password", %{
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
      assert to_string(reloaded.email) == "before@example.com"
      assert reloaded.pending_email_change["new_email"] == "after@example.com"

      Oban.drain_queue(queue: :notifications)

      assert_receive {:email,
                      %Swoosh.Email{
                        subject: "Approve your huddlz email change",
                        to: [{"", "before@example.com"}]
                      }}

      assert_receive {:email,
                      %Swoosh.Email{
                        subject: "Approve your huddlz email change",
                        to: [{"", "after@example.com"}]
                      }}
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

      refute_enqueued(worker: EmailChangeDelivery)
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

      refute_enqueued(worker: EmailChangeDelivery)
    end
  end
end
