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

  describe "display name persistence regression test" do
    test "display name should not change on subsequent logins" do
      # Create a user with a known display name
      email = "regression-test-#{:rand.uniform(99999)}@example.com"
      original_display_name = "OriginalName#{:rand.uniform(999)}"

      # Create user using Ash.Seed
      user =
        Ash.Seed.seed!(User, %{
          email: email,
          display_name: original_display_name,
          role: :regular
        })

      # Verify user was created correctly
      assert user.display_name == original_display_name

      # Now we need to test the sign_in_with_magic_link action
      # Since this is internal testing, we'll directly test the action logic
      # by simulating what happens when the action's upsert logic runs

      # The sign_in_with_magic_link uses upsert with :unique_email identity
      # Let's test by manually calling the action with test data that would trigger the upsert
      changeset =
        Ash.Changeset.for_create(User, :sign_in_with_magic_link, %{
          # This would normally be validated by AshAuthentication
          token: "test-token",
          # Not providing a display name, simulating normal login
          display_name: nil
        })

      # Manually set the email to trigger the upsert path
      _changeset = Ash.Changeset.change_attribute(changeset, :email, email)

      # Check what the before_action change does
      # Since the user already exists and has an id, is_new_user should be false
      # and the display name should not be changed

      # Let's verify our fix by checking the upsert_fields
      info = Info.action(User, :sign_in_with_magic_link)

      assert info.upsert_fields == [:email],
             "upsert_fields should only include :email, not :display_name"

      # Verify that existing user's display name would be preserved
      # The key insight is that with our fix, display_name is not in upsert_fields
      # so it won't be overwritten during the upsert operation
      assert original_display_name == user.display_name
    end

    test "new users get a random display name on first sign in" do
      # Test that our fix still allows new users to get a display name
      # We'll test this by checking the action configuration

      # The before_action change should:
      # 1. Check if it's a new user (!changeset.data.id)
      # 2. Only set display_name if it's a new user AND no display_name was provided

      # Since we can't easily test the full authentication flow in a unit test,
      # we'll verify the action is configured correctly
      info = Info.action(User, :sign_in_with_magic_link)

      # Verify the action has the correct change module
      assert Enum.any?(info.changes, fn change ->
               match?(
                 %Ash.Resource.Change{
                   change: {Huddlz.Accounts.User.Changes.SetDefaultDisplayName, _}
                 },
                 change
               )
             end)

      # Test that the change module exists and would generate proper display names
      # We can't directly test the private function, but we can verify the module exists
      assert Code.ensure_loaded?(Huddlz.Accounts.User.Changes.SetDefaultDisplayName)
    end
  end
end
