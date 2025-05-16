defmodule Huddlz.Accounts.AdminAuthorizationTest do
  @moduledoc """
  Tests for the admin authorization functionality in the User resource.
  Following the Ash.Test patterns from https://hexdocs.pm/ash/test-resources.html
  """

  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Accounts

  setup do
    # Create an admin user for testing
    admin_user =
      Ash.Seed.seed!(User, %{
        email: "admin-test-auth@example.com",
        display_name: "Admin Test Auth",
        role: :admin
      })

    # Create a regular user for testing
    regular_user =
      Ash.Seed.seed!(User, %{
        email: "regular-test-auth@example.com",
        display_name: "Regular Test Auth",
        role: :regular
      })

    # Create a verified user for testing
    verified_user =
      Ash.Seed.seed!(User, %{
        email: "verified-test-auth@example.com",
        display_name: "Verified Test Auth",
        role: :verified
      })

    {:ok, %{admin: admin_user, regular: regular_user, verified: verified_user}}
  end

  describe "admin permissions" do
    test "admin authorization checks", %{admin: admin, regular: regular, verified: verified} do
      # Test role helper functions
      assert Accounts.admin?(admin)
      refute Accounts.admin?(regular)
      refute Accounts.admin?(verified)

      assert Accounts.verified?(admin)
      assert Accounts.verified?(verified)
      refute Accounts.verified?(regular)
    end

    test "admin users can search by email", %{admin: admin, regular: regular, verified: verified} do
      # Test search_by_email with different actors
      assert {:ok, results} = Accounts.search_by_email("example", actor: admin)
      assert is_list(results)

      # Regular and verified users receive empty results for security
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
      # Directly test the helper function
      assert Accounts.check_permission(:update_role, admin) == true
      assert Accounts.check_permission(:update_role, regular) == false
      assert Accounts.check_permission(:update_role, verified) == false

      # Test that regular users cannot update roles
      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.update_role!(verified, :regular, actor: regular)
      end
    end
  end
end
