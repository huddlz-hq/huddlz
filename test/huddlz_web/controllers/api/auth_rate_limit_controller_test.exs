defmodule HuddlzWeb.Api.AuthRateLimitControllerTest do
  @moduledoc """
  The auth controller maps the action-layer rate limit to a 429 with a Retry-After.
  """
  # async: false — the limiter's ETS counter is shared process-globally, not sandboxed.
  use HuddlzWeb.ApiCase, async: false

  import Huddlz.RateLimitTestHelper

  setup do
    enable_rate_limiting()
  end

  defp limit_for(action), do: Application.fetch_env!(:huddlz, :auth_rate_limits)[action][:limit]
  defp email(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}@example.com"

  test "POST /api/auth/sign_in returns 429 with Retry-After once the limit is hit" do
    params = %{"email" => email("api-rl-signin"), "password" => "wrong-password"}

    for _ <- 1..limit_for(:sign_in) do
      assert post(build_conn(), "/api/auth/sign_in", params).status == 401
    end

    resp = post(build_conn(), "/api/auth/sign_in", params)
    assert %{"error" => _} = json_response(resp, 429)
    assert [retry_after] = get_resp_header(resp, "retry-after")
    assert String.to_integer(retry_after) > 0
  end

  test "POST /api/auth/register returns 429 once the limit is hit" do
    params = %{
      "email" => email("api-rl-register"),
      "display_name" => "Rate Limit",
      "password" => "password123",
      "password_confirmation" => "password123",
      "legal_acceptance" => true
    }

    for _ <- 1..limit_for(:register), do: post(build_conn(), "/api/auth/register", params)

    assert %{"error" => _} = json_response(post(build_conn(), "/api/auth/register", params), 429)
  end

  test "POST /api/auth/password_reset returns 429 once the limit is hit" do
    params = %{"email" => email("api-rl-reset")}

    for _ <- 1..limit_for(:password_reset) do
      assert post(build_conn(), "/api/auth/password_reset", params).status == 204
    end

    assert %{"error" => _} =
             json_response(post(build_conn(), "/api/auth/password_reset", params), 429)
  end

  test "DELETE /api/auth/account returns 429 with Retry-After once the limit is hit" do
    user_email = email("api-rl-delete")

    %{"token" => token} =
      post(build_conn(), "/api/auth/register", %{
        "email" => user_email,
        "display_name" => "Rate Limit Delete",
        "password" => "password123",
        "password_confirmation" => "password123",
        "legal_acceptance" => true
      })
      |> json_response(201)

    authed = fn ->
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
    end

    for _ <- 1..limit_for(:delete_account) do
      assert delete(authed.(), "/api/auth/account", %{"password" => "wrong-password"}).status ==
               422
    end

    resp = delete(authed.(), "/api/auth/account", %{"password" => "wrong-password"})
    assert %{"error" => _} = json_response(resp, 429)
    assert [retry_after] = get_resp_header(resp, "retry-after")
    assert String.to_integer(retry_after) > 0
  end
end
