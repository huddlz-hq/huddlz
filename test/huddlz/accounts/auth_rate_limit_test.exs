defmodule Huddlz.Accounts.AuthRateLimitTest do
  @moduledoc """
  The auth actions are rate limited per email at the action layer, so the limit
  applies no matter how the action is invoked. These tests drive the actions
  directly and assert the limit surfaces as `AshRateLimiter.LimitExceeded`.
  """
  # async: false — the limiter's ETS counter is shared process-globally, not sandboxed.
  use Huddlz.DataCase, async: false

  import Huddlz.RateLimitTestHelper

  alias Huddlz.Accounts.User

  setup do
    enable_rate_limiting()
  end

  defp limit_for(action), do: Application.fetch_env!(:huddlz, :auth_rate_limits)[action][:limit]

  defp email(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}@example.com"

  # LimitExceeded is a :forbidden-class error, so it arrives nested inside Ash's
  # error wrappers — walk the tree for it.
  defp limit_exceeded?(%AshRateLimiter.LimitExceeded{}), do: true

  defp limit_exceeded?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &limit_exceeded?/1)

  defp limit_exceeded?(errors) when is_list(errors), do: Enum.any?(errors, &limit_exceeded?/1)
  defp limit_exceeded?(_), do: false

  describe "sign_in_with_password" do
    defp sign_in(email) do
      User
      |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: "wrong-password"})
      |> Ash.read_one()
    end

    test "is rate limited per email after the configured number of attempts" do
      email = email("rl-signin")
      limit = limit_for(:sign_in)

      # Each attempt fails auth, but every attempt counts toward the limit.
      for _ <- 1..limit do
        assert {:error, error} = sign_in(email)
        refute limit_exceeded?(error)
      end

      assert {:error, error} = sign_in(email)
      assert limit_exceeded?(error)
    end

    test "a different email has its own bucket" do
      blocked = email("rl-signin")
      for _ <- 1..(limit_for(:sign_in) + 1), do: sign_in(blocked)

      # A fresh email is unaffected by the blocked one.
      assert {:error, error} = sign_in(email("rl-signin"))
      refute limit_exceeded?(error)
    end
  end

  describe "register_with_password" do
    defp register(email) do
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        display_name: "Rate Limit Test",
        password: "password123",
        password_confirmation: "password123"
      })
      |> Ash.create()
    end

    test "is rate limited per email after the configured number of attempts" do
      email = email("rl-register")
      limit = limit_for(:register)

      # The first attempt creates the user; later same-email attempts fail
      # uniqueness, but all count toward the limit.
      for _ <- 1..limit, do: register(email)

      assert {:error, error} = register(email)
      assert limit_exceeded?(error)
    end
  end

  describe "request_password_reset_token" do
    defp request_reset(email) do
      User
      |> Ash.ActionInput.for_action(:request_password_reset_token, %{email: email})
      |> Ash.run_action()
    end

    test "is rate limited per email after the configured number of attempts" do
      email = email("rl-reset")
      limit = limit_for(:password_reset)

      for _ <- 1..limit, do: request_reset(email)

      assert {:error, error} = request_reset(email)
      assert limit_exceeded?(error)
    end
  end
end
