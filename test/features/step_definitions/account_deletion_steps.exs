defmodule AccountDeletionSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 5, json_response: 2]

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, GroupMember, Huddl, HuddlAttendee}

  @endpoint HuddlzWeb.Endpoint

  # ── the app ─────────────────────────────────────────────────────────

  step "{string} is signed in to the app with password {string}",
       %{args: [email, password]} = context do
    body =
      api_conn()
      |> dispatch(@endpoint, :post, "/api/auth/sign_in", %{email: email, password: password})
      |> json_response(200)

    Map.merge(context, %{app_token: body["token"], app_user: find_user(email)})
  end

  step "{string} deletes their account in the app with password {string}",
       %{args: [email, password]} = context do
    user = find_user(email)

    conn =
      context.app_token
      |> bearer_conn()
      |> dispatch(@endpoint, :delete, "/api/auth/account", %{password: password})

    Map.merge(context, %{deletion_response: conn, deleted_user_id: user.id})
  end

  step "the account is deleted", context do
    assert context.deletion_response.status == 204
    assert %DateTime{} = deleted_user(context).deleted_at
    context
  end

  step "the account deletion is refused with {string}", %{args: [message]} = context do
    body = json_response(context.deletion_response, 422)
    assert Enum.any?(body["errors"], &(&1["message"] == message))
    refute deleted_user(context).deleted_at
    context
  end

  step "the app is signed out of the deleted account", context do
    conn =
      context.app_token
      |> bearer_conn()
      |> dispatch(@endpoint, :get, "/api/auth/me", %{})

    assert conn.status == 401
    context
  end

  step "the app is still signed in as {string}", %{args: [name]} = context do
    body =
      context.app_token
      |> bearer_conn()
      |> dispatch(@endpoint, :get, "/api/auth/me", %{})
      |> json_response(200)

    assert body["user"]["display_name"] == name
    context
  end

  step "nobody can sign in to the app as {string} with password {string}",
       %{args: [email, password]} = context do
    conn =
      dispatch(api_conn(), @endpoint, :post, "/api/auth/sign_in", %{
        email: email,
        password: password
      })

    assert conn.status == 401
    context
  end

  step "someone can register in the app as {string}", %{args: [email]} = context do
    body =
      api_conn()
      |> dispatch(@endpoint, :post, "/api/auth/register", %{
        display_name: "Fresh Start",
        email: email,
        password: "Password456!",
        password_confirmation: "Password456!",
        legal_acceptance: true
      })
      |> json_response(201)

    assert body["user"]["email"] == email
    refute body["user"]["id"] == context.deleted_user_id
    context
  end

  # ── what remains ────────────────────────────────────────────────────

  step "the deleted account keeps no personal details", context do
    user = deleted_user(context)
    original = context.app_user

    refute to_string(user.email) == to_string(original.email)
    assert user.display_name == "Deleted member"
    refute user.hashed_password
    refute user.home_location
    refute user.pending_email_change
    context
  end

  step "the deleted account is no longer a member of {string}", %{args: [name]} = context do
    group = Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)

    refute GroupMember
           |> Ash.Query.filter(group_id == ^group.id and user_id == ^context.deleted_user_id)
           |> Ash.exists?(authorize?: false)

    context
  end

  step "the deleted account is no longer attending {string}", %{args: [title]} = context do
    huddl = find_huddl(title)

    refute HuddlAttendee
           |> Ash.Query.filter(huddl_id == ^huddl.id and user_id == ^context.deleted_user_id)
           |> Ash.exists?(authorize?: false)

    context
  end

  step "the group {string} is archived", %{args: [name]} = context do
    assert %DateTime{} = group_with_archived(name).archived_at
    context
  end

  step "the group {string} is not archived", %{args: [name]} = context do
    refute group_with_archived(name).archived_at
    context
  end

  step "the huddl {string} is cancelled", %{args: [title]} = context do
    assert find_huddl(title).lifecycle_state == :cancelled
    context
  end

  # ── helpers ─────────────────────────────────────────────────────────

  defp api_conn do
    build_conn()
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  defp bearer_conn(token),
    do: Plug.Conn.put_req_header(api_conn(), "authorization", "Bearer " <> token)

  defp deleted_user(context), do: Ash.get!(User, context.deleted_user_id, authorize?: false)

  defp group_with_archived(name) do
    Group
    |> Ash.Query.for_read(:read_with_archived)
    |> Ash.Query.filter(name == ^name)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.for_read(:read_for_group_lifecycle)
    |> Ash.Query.filter(title == ^title)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end
end
