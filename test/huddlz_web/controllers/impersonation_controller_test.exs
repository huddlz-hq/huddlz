defmodule HuddlzWeb.ImpersonationControllerTest do
  use HuddlzWeb.ConnCase, async: false
  @moduletag :impersonation_controller

  alias AshAuthentication.TokenResource.Actions, as: Tokens
  alias Huddlz.Accounts.Token
  alias Huddlz.Admin.Impersonation
  alias HuddlzWeb.ApiCase

  setup do
    %{admin: generate(user(role: :admin)), target: generate(user())}
  end

  test "direct requests refuse nonadmins, self targets, and admin targets", ctx do
    other_admin = generate(user(role: :admin))

    for {actor, target} <- [
          {ctx.target, ctx.admin},
          {ctx.admin, ctx.admin},
          {ctx.admin, other_admin}
        ] do
      conn = build_conn() |> login(actor) |> post(~p"/admin/impersonations/#{target.id}")
      assert redirected_to(conn) in ["/agenda", "/admin/users"]
      refute get_session(conn, :impersonation_id)
    end

    assert [] == Ash.read!(Impersonation, authorize?: false)
  end

  test "stopping restores the original token and ends the record", ctx do
    conn = build_conn() |> login(ctx.admin)
    original_token = get_session(conn, :user_token)
    conn = post(conn, ~p"/admin/impersonations/#{ctx.target.id}")
    id = get_session(conn, :impersonation_id)
    assert id
    refute get_session(conn, :user_token) == original_token

    conn = conn |> recycle() |> delete(~p"/admin/impersonations/current")
    assert redirected_to(conn) == "/admin/users"
    assert get_session(conn, :user_token) == original_token
    refute get_session(conn, :impersonator_token)
    refute get_session(conn, :impersonation_id)
    assert Ash.get!(Impersonation, id, authorize?: false).ended_at
  end

  test "signing out clears both identities and stops impersonation", ctx do
    conn = build_conn() |> login(ctx.admin) |> post(~p"/admin/impersonations/#{ctx.target.id}")
    id = get_session(conn, :impersonation_id)
    conn = conn |> recycle() |> delete(~p"/sign-out")
    refute get_session(conn, :user_token)
    refute get_session(conn, :impersonator_token)
    refute get_session(conn, :impersonation_id)
    assert Ash.get!(Impersonation, id, authorize?: false).ended_at
  end

  test "confirming another account finalizes impersonation before replacing the identity", ctx do
    other = generate(user_with_password())
    confirmation_token = other.__metadata__.confirmation_token

    conn = build_conn() |> login(ctx.admin) |> post(~p"/admin/impersonations/#{ctx.target.id}")
    id = get_session(conn, :impersonation_id)
    target_token = get_session(conn, :user_token)
    admin_token = get_session(conn, :impersonator_token)
    topic = get_session(conn, :live_socket_id)
    HuddlzWeb.Endpoint.subscribe(topic)

    conn =
      conn
      |> recycle()
      |> post(~p"/auth/user/confirm_new_user", user: %{confirm: confirmation_token})

    assert conn.assigns.current_user.id == other.id
    assert Ash.get!(Impersonation, id, authorize?: false).ended_at
    refute get_session(conn, :impersonation_id)
    refute get_session(conn, :impersonator_token)
    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect"}

    for token <- [target_token, admin_token] do
      assert Tokens.token_revoked?(Token, token)
    end

    replacement_token = get_session(conn, :user_token)

    refute Tokens.token_revoked?(
             Token,
             replacement_token
           )

    conn = conn |> recycle() |> delete(~p"/sign-out")
    refute get_session(conn, :user_token)
    assert Ash.get!(Impersonation, id, authorize?: false).ended_at

    assert Tokens.token_revoked?(
             Token,
             replacement_token
           )
  end

  test "failed authentication keeps the current impersonation open", ctx do
    conn = build_conn() |> login(ctx.admin) |> post(~p"/admin/impersonations/#{ctx.target.id}")
    id = get_session(conn, :impersonation_id)
    target_token = get_session(conn, :user_token)
    admin_token = get_session(conn, :impersonator_token)

    conn =
      conn
      |> recycle()
      |> post(~p"/auth/user/confirm_new_user", user: %{confirm: "invalid"})

    assert redirected_to(conn) == "/sign-in"
    assert get_session(conn, :impersonation_id) == id
    assert get_session(conn, :user_token) == target_token
    assert get_session(conn, :impersonator_token) == admin_token
    refute Ash.get!(Impersonation, id, authorize?: false).ended_at

    for token <- [target_token, admin_token] do
      refute Tokens.token_revoked?(Token, token)
    end
  end

  test "bearer authentication keeps its own identity during browser impersonation", ctx do
    group = generate(group(actor: ctx.target, is_public: false))
    conn = build_conn() |> login(ctx.admin) |> post(~p"/admin/impersonations/#{ctx.target.id}")

    result =
      conn
      |> recycle()
      |> ApiCase.authenticated_conn(ctx.admin)
      |> ApiCase.gql_post("{ listGroups { results { id } } }")
      |> json_response(200)

    assert result["data"]["listGroups"]["results"] == []

    result =
      conn
      |> recycle()
      |> ApiCase.authenticated_conn(ctx.target)
      |> ApiCase.gql_post("{ listGroups { results { id } } }")
      |> json_response(200)

    assert result["data"]["listGroups"]["results"] == [%{"id" => group.id}]
  end

  test "session resolution only returns an active record for its target", ctx do
    record = Huddlz.Admin.start_impersonation!(ctx.target.id, actor: ctx.admin)

    assert {:ok, resolved} =
             Huddlz.Admin.resolve_impersonation_session(record.id, actor: ctx.target)

    assert resolved.id == record.id
    assert resolved.admin.id == ctx.admin.id
    assert resolved.user.id == ctx.target.id

    assert {:ok, nil} =
             Huddlz.Admin.resolve_impersonation_session(record.id, actor: ctx.admin)

    assert {:ok, nil} =
             Huddlz.Admin.resolve_impersonation_session(record.id, actor: generate(user()))

    assert {:error, _} = Huddlz.Admin.resolve_impersonation_session(record.id)

    Huddlz.Admin.stop_impersonation!(record, actor: ctx.admin)

    assert {:ok, nil} =
             Huddlz.Admin.resolve_impersonation_session(record.id, actor: ctx.target)
  end

  test "pages render without impersonation controls for an ended session", ctx do
    record = Huddlz.Admin.start_impersonation!(ctx.target.id, actor: ctx.admin)
    Huddlz.Admin.stop_impersonation!(record, actor: ctx.admin)

    assert_rejected_session_pages(ctx.target, record.id)
  end

  test "pages render without impersonation controls for a missing session", ctx do
    assert_rejected_session_pages(ctx.target, Ash.UUID.generate())
  end

  test "pages render without impersonation controls for another person's session", ctx do
    record = Huddlz.Admin.start_impersonation!(generate(user()).id, actor: ctx.admin)

    assert_rejected_session_pages(ctx.target, record.id)
  end

  test "an active impersonation cannot be nested", ctx do
    conn = build_conn() |> login(ctx.admin) |> post(~p"/admin/impersonations/#{ctx.target.id}")
    id = get_session(conn, :impersonation_id)
    conn = conn |> recycle() |> post(~p"/admin/impersonations/#{ctx.admin.id}")
    assert redirected_to(conn) == "/agenda"
    assert get_session(conn, :impersonation_id) == id
    assert length(Ash.read!(Impersonation, authorize?: false)) == 1
  end

  defp assert_rejected_session_pages(user, id) do
    token = Huddlz.Notifications.unsubscribe_token(user, :rsvp_received)

    build_conn()
    |> login(user)
    |> put_session(:impersonation_id, id)
    |> visit("/help")
    |> assert_has("h1", text: "Help")
    |> refute_has("[role='region'][aria-label='Impersonation']")
    |> visit("/unsubscribe/#{token}")
    |> assert_has("h1", text: "Confirm unsubscribe")
    |> refute_has("[role='region'][aria-label='Impersonation']")
  end
end
