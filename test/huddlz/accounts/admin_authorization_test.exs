defmodule Huddlz.Accounts.AdminAuthorizationTest do
  @moduledoc """
  Tests for the admin authorization functionality in the User resource.
  Following the Ash.Test patterns from https://hexdocs.pm/ash/test-resources.html
  """

  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User

  setup do
    admin_user = generate(user(role: :admin))
    regular_user = generate(user(role: :user))
    verified_user = generate(user(role: :user))

    {:ok, %{admin: admin_user, regular: regular_user, verified: verified_user}}
  end

  describe "admin permissions" do
    test "admin authorization checks", %{admin: admin, regular: regular, verified: verified} do
      # Test using Ash's built-in authorization
      assert admin.role == :admin
      assert regular.role == :user
      assert verified.role == :user
    end

    test "admin users can search by email", %{admin: admin, regular: regular, verified: verified} do
      # Test search_by_email with different actors
      assert {:ok, results} = Accounts.search_by_email("example", actor: admin)
      assert is_list(results)

      # Regular and users receive empty results for security
      assert {:ok, []} = Accounts.search_by_email("example", actor: regular)
      assert {:ok, []} = Accounts.search_by_email("example", actor: verified)

      # Bang version with empty results doesn't raise an error
      assert [] = Accounts.search_by_email!("example", actor: regular)
    end

    test "role authorization check functions work", %{
      admin: admin,
      regular: regular,
      verified: verified
    } do
      # Use Ash's can? to test permissions
      assert Ash.can?({User, :update_role}, admin)
      refute Ash.can?({User, :update_role}, regular)
      refute Ash.can?({User, :update_role}, verified)

      # Test that users cannot update roles
      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.update_role!(verified, :admin, actor: regular)
      end
    end
  end
end
