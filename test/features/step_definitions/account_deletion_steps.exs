defmodule AccountDeletionSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 5, json_response: 2]

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, GroupInvitation, GroupMember, Huddl, HuddlAttendee}
  alias Huddlz.Notifications.Notification

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

  step "{string} tries to delete their account in the app without a password",
       %{args: [email]} = context do
    user = find_user(email)

    conn =
      context.app_token
      |> bearer_conn()
      |> dispatch(@endpoint, :delete, "/api/auth/account", %{})

    Map.merge(context, %{deletion_response: conn, deleted_user_id: user.id})
  end

  step "{string} is an admin", %{args: [email]} = context do
    user = find_user(email)

    user
    |> Ash.Changeset.for_update(:update_role, %{role: :admin}, authorize?: false)
    |> Ash.update!()

    context
  end

  step "a draft huddl {string} exists in group {string} hosted by {string}",
       %{args: [title, group_name, email]} = context do
    group = group_with_archived(group_name)
    host = find_user(email)
    starts_at = DateTime.add(DateTime.utc_now(), 48, :hour)
    ends_at = DateTime.add(starts_at, 2, :hour)

    Huddl
    |> Ash.Changeset.for_create(
      :create,
      %{
        title: title,
        starts_at: starts_at,
        ends_at: ends_at,
        event_type: :virtual,
        virtual_link: "https://example.com/draft",
        lifecycle_state: :draft,
        group_id: group.id
      },
      actor: host
    )
    |> Ash.create!()

    context
  end

  step "{string} invited {string} to {string}",
       %{args: [inviter_email, invitee_email, group_name]} = context do
    inviter = find_user(inviter_email)
    group = group_with_archived(group_name)

    GroupInvitation
    |> Ash.Changeset.for_create(
      :invite,
      %{group_id: group.id, email: invitee_email, role: :member},
      actor: inviter
    )
    |> Ash.create!()

    context
  end

  step "{string} has a notification naming {string}",
       %{args: [recipient_email, named_email]} = context do
    recipient = find_user(recipient_email)
    named = find_user(named_email)

    Notification
    |> Ash.Changeset.for_create(
      :create,
      %{
        user_id: recipient.id,
        trigger: :new_rsvp,
        title: "New RSVP",
        description: "#{named.display_name} is going",
        payload: %{
          "rsvper_id" => named.id,
          "rsvper_display_name" => named.display_name
        }
      },
      authorize?: false
    )
    |> Ash.create!()

    context
  end

  step "{string} has a notification", %{args: [email]} = context do
    recipient = find_user(email)

    Notification
    |> Ash.Changeset.for_create(
      :create,
      %{
        user_id: recipient.id,
        trigger: :new_rsvp,
        title: "Hello",
        description: "Test notification",
        payload: %{}
      },
      authorize?: false
    )
    |> Ash.create!()

    context
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

  step "the deleted account has role {string}", %{args: [role]} = context do
    assert to_string(deleted_user(context).role) == role
    context
  end

  step "no invitation exists for {string}", %{args: [email]} = context do
    refute GroupInvitation
           |> Ash.Query.filter(invitee_id == ^context.deleted_user_id or email == ^email)
           |> Ash.exists?(authorize?: false)

    context
  end

  step "the draft huddl {string} no longer exists", %{args: [title]} = context do
    refute find_huddl(title)
    context
  end

  step "the huddl {string} still exists", %{args: [title]} = context do
    assert find_huddl(title)
    context
  end

  step "{string} archived the group {string}", %{args: [email, name]} = context do
    owner = find_user(email)
    group = group_with_archived(name)

    group
    |> Ash.Changeset.for_destroy(:archive, %{}, actor: owner)
    |> Ash.destroy!()

    context
  end

  step "the deleted account has no notifications", context do
    refute Notification
           |> Ash.Query.filter(user_id == ^context.deleted_user_id)
           |> Ash.exists?(authorize?: false)

    context
  end

  step "notifications for {string} show {string} instead of {string}",
       %{args: [email, expected, forbidden]} = context do
    recipient = find_user(email)

    notifications =
      Notification
      |> Ash.Query.for_read(:for_user, %{}, actor: recipient)
      |> Ash.read!(actor: recipient)

    assert notifications != []

    assert Enum.any?(notifications, &(&1.payload["rsvper_display_name"] == expected))
    refute Enum.any?(notifications, &(&1.payload["rsvper_display_name"] == forbidden))
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
