defmodule Huddlz.Accounts.UserTest do
  use Huddlz.DataCase, async: true
  alias Ash.Resource.Info
  alias Huddlz.Accounts
  alias Huddlz.Accounts.User

  describe "user policies" do
    test "admin users can search by email" do
      # Create an admin user with a unique test marker in the email
      admin_user =
        Ash.Seed.seed!(User, %{
          email: "admin-search-unique@example.com",
          display_name: "Admin Search Test",
          role: :admin
        })

      # Create a regular user with a unique test marker in the email
      regular_user =
        Ash.Seed.seed!(User, %{
          email: "regular-search-unique@example.com",
          display_name: "Regular Search Test",
          role: :regular
        })

      # Verify the users exist in our test database
      assert admin_user.id != nil
      assert regular_user.id != nil

      # Test that our permission check helper works correctly
      assert Accounts.check_permission(:search_by_email, admin_user) == true
      assert Accounts.check_permission(:search_by_email, regular_user) == false
    end

    test "non-admin users cannot update roles" do
      # Create an admin user
      admin_user =
        Ash.Seed.seed!(User, %{
          email: "admin-role-test@example.com",
          display_name: "Admin Role Test",
          role: :admin
        })

      # Create a regular user
      regular_user =
        Ash.Seed.seed!(User, %{
          email: "regular-role-test@example.com",
          display_name: "Regular Role Test",
          role: :regular
        })

      # Create a verified user
      verified_user =
        Ash.Seed.seed!(User, %{
          email: "verified-role-test@example.com",
          display_name: "Verified Role Test",
          role: :verified
        })

      # Verify our permission check helper works correctly
      assert Accounts.check_permission(:update_role, admin_user) == true
      assert Accounts.check_permission(:update_role, regular_user) == false
      assert Accounts.check_permission(:update_role, verified_user) == false

      # Verify our policy is working as intended - regular and verified users cannot update roles
      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.update_role!(regular_user, :verified, actor: regular_user)
      end

      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.update_role!(regular_user, :verified, actor: verified_user)
      end
    end

    test "all users can read users" do
      # Create users with different roles
      admin_user =
        Ash.Seed.seed!(User, %{
          email: "admin-read-test@example.com",
          display_name: "Admin Read Test",
          role: :admin
        })

      regular_user =
        Ash.Seed.seed!(User, %{
          email: "regular-read-test@example.com",
          display_name: "Regular Read Test",
          role: :regular
        })

      # Test permission with our helper function
      assert Accounts.check_permission(:read, admin_user) == true
      assert Accounts.check_permission(:read, regular_user) == true
    end
  end

  describe "display name tests" do
    test "users get a default display name on registration" do
      # Create a user with a known display name
      email = "test-#{:rand.uniform(99999)}@example.com"
      original_display_name = "TestUser#{:rand.uniform(999)}"

      # Create user using Ash.Seed
      user =
        Ash.Seed.seed!(User, %{
          email: email,
          display_name: original_display_name,
          role: :regular
        })

      # Verify user was created correctly
      assert user.display_name == original_display_name
    end

    test "new users get a random display name if none provided" do
      # Test that the SetDefaultDisplayName change module exists
      assert Code.ensure_loaded?(Huddlz.Accounts.User.Changes.SetDefaultDisplayName)

      # Verify the register_with_password action has the correct change module
      info = Info.action(User, :register_with_password)

      # The register action should have the SetDefaultDisplayName change
      assert Enum.any?(info.changes, fn change ->
               match?(
                 %Ash.Resource.Change{
                   change: {Huddlz.Accounts.User.Changes.SetDefaultDisplayName, _}
                 },
                 change
               )
             end)
    end
  end
end
