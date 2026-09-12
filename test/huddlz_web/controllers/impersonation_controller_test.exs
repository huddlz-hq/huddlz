defmodule HuddlzWeb.ImpersonationControllerTest do
  use HuddlzWeb.ConnCase, async: false
  @moduletag :impersonation_controller

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

  test "an active impersonation cannot be nested", ctx do
    conn = build_conn() |> login(ctx.admin) |> post(~p"/admin/impersonations/#{ctx.target.id}")
    id = get_session(conn, :impersonation_id)
    conn = conn |> recycle() |> post(~p"/admin/impersonations/#{ctx.admin.id}")
    assert redirected_to(conn) == "/agenda"
    assert get_session(conn, :impersonation_id) == id
    assert length(Ash.read!(Impersonation, authorize?: false)) == 1
  end
end
