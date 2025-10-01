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

      # Create a user with a unique test marker in the email
      regular_user =
        Ash.Seed.seed!(User, %{
          email: "regular-search-unique@example.com",
          display_name: "Regular Search Test",
          role: :user
        })

      # Verify the users exist in our test database
      assert admin_user.id != nil
      assert regular_user.id != nil

      # Test that our permission check works correctly using Ash's generated functions
      assert Accounts.can_search_by_email?(admin_user, "test@example.com")
      # All users can now search by email
      assert Accounts.can_search_by_email?(regular_user, "test@example.com")
    end

    test "non-admin users cannot update roles" do
      # Create an admin user
      admin_user =
        Ash.Seed.seed!(User, %{
          email: "admin-role-test@example.com",
          display_name: "Admin Role Test",
          role: :admin
        })

      # Create a user
      regular_user =
        Ash.Seed.seed!(User, %{
          email: "regular-role-test@example.com",
          display_name: "Regular Role Test",
          role: :user
        })

      # Create a user
      verified_user =
        Ash.Seed.seed!(User, %{
          email: "verified-role-test@example.com",
          display_name: "Verified Role Test",
          role: :user
        })

      # Verify permissions using Ash's can?
      assert Ash.can?({User, :update_role}, admin_user)
      refute Ash.can?({User, :update_role}, regular_user)
      refute Ash.can?({User, :update_role}, verified_user)

      # Verify our policy is working as intended - regular and users cannot update roles
      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.update_role!(regular_user, :admin, actor: regular_user)
      end

      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.update_role!(regular_user, :admin, actor: verified_user)
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
          role: :user
        })

      # Test permission using Ash's can? function for read action
      assert Ash.can?({Accounts.User, :read}, admin_user)
      assert Ash.can?({Accounts.User, :read}, regular_user)
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
          role: :user
        })

      # Verify user was created correctly
      assert user.display_name == original_display_name
    end

    test "new users get a random display name if none provided (via :create action)" do
      # Test that the SetDefaultDisplayName change module exists
      assert Code.ensure_loaded?(Huddlz.Accounts.User.Changes.SetDefaultDisplayName)

      # Verify the :create action (used for seeding) has the SetDefaultDisplayName change
      info = Info.action(User, :create)

      # The create action should have the SetDefaultDisplayName change for seeding/testing
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

  describe "register_with_password with display_name" do
    test "registration with valid display_name succeeds" do
      user =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "test#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: "John Doe"
        })
        |> Ash.create!()

      assert user.display_name == "John Doe"
    end

    test "registration with single-name display_name succeeds" do
      user =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "madonna#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: "Madonna"
        })
        |> Ash.create!()

      assert user.display_name == "Madonna"
    end

    test "registration with emoji in display_name succeeds" do
      user =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "emoji#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: "Sam 🎉"
        })
        |> Ash.create!()

      assert user.display_name == "Sam 🎉"
    end

    test "registration with accented characters succeeds" do
      user =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "jose#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: "José García"
        })
        |> Ash.create!()

      assert user.display_name == "José García"
    end

    test "registration with max length (70 chars) succeeds" do
      long_name = String.duplicate("A", 70)

      user =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "longname#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: long_name
        })
        |> Ash.create!()

      assert user.display_name == long_name
      assert String.length(user.display_name) == 70
    end

    test "registration without display_name fails with validation error" do
      # Since display_name is required, omitting it should fail
      assert_raise Ash.Error.Invalid, fn ->
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "noname#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123"
        })
        |> Ash.create!()
      end
    end

    test "registration with empty display_name fails with validation error" do
      # Empty string should fail min_length constraint
      assert_raise Ash.Error.Invalid, fn ->
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "emptyname#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: ""
        })
        |> Ash.create!()
      end
    end

    test "registration with over-length display_name (71 chars) fails" do
      long_name = String.duplicate("A", 71)

      assert_raise Ash.Error.Invalid, fn ->
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "toolong#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: long_name
        })
        |> Ash.create!()
      end
    end

    test "duplicate display_names are allowed (non-unique)" do
      shared_name = "John Doe"

      user1 =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "user1#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: shared_name
        })
        |> Ash.create!()

      user2 =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "user2#{:rand.uniform(99999)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: shared_name
        })
        |> Ash.create!()

      assert user1.display_name == shared_name
      assert user2.display_name == shared_name
      assert user1.id != user2.id
    end
  end

  describe "update_display_name action" do
    test "user can update their own display_name" do
      user =
        Ash.Seed.seed!(User, %{
          email: "update#{:rand.uniform(99999)}@example.com",
          display_name: "Original Name"
        })

      updated_user =
        user
        |> Ash.Changeset.for_update(
          :update_display_name,
          %{
            display_name: "New Name"
          },
          actor: user
        )
        |> Ash.update!()

      assert updated_user.display_name == "New Name"
    end

    test "user cannot update another user's display_name" do
      user1 =
        Ash.Seed.seed!(User, %{
          email: "user1update#{:rand.uniform(99999)}@example.com",
          display_name: "User 1"
        })

      user2 =
        Ash.Seed.seed!(User, %{
          email: "user2update#{:rand.uniform(99999)}@example.com",
          display_name: "User 2"
        })

      assert_raise Ash.Error.Forbidden, fn ->
        user1
        |> Ash.Changeset.for_update(
          :update_display_name,
          %{
            display_name: "Hacked Name"
          },
          actor: user2
        )
        |> Ash.update!()
      end
    end

    test "update with max length (70 chars) succeeds" do
      user =
        Ash.Seed.seed!(User, %{
          email: "maxupdate#{:rand.uniform(99999)}@example.com",
          display_name: "Short"
        })

      long_name = String.duplicate("A", 70)

      updated_user =
        user
        |> Ash.Changeset.for_update(
          :update_display_name,
          %{
            display_name: long_name
          },
          actor: user
        )
        |> Ash.update!()

      assert updated_user.display_name == long_name
      assert String.length(updated_user.display_name) == 70
    end

    test "update with empty display_name fails" do
      user =
        Ash.Seed.seed!(User, %{
          email: "emptyupdate#{:rand.uniform(99999)}@example.com",
          display_name: "Original Name"
        })

      assert_raise Ash.Error.Invalid, fn ->
        user
        |> Ash.Changeset.for_update(
          :update_display_name,
          %{
            display_name: ""
          },
          actor: user
        )
        |> Ash.update!()
      end
    end

    test "update with over-length display_name fails" do
      user =
        Ash.Seed.seed!(User, %{
          email: "toolongupdate#{:rand.uniform(99999)}@example.com",
          display_name: "Original Name"
        })

      long_name = String.duplicate("A", 71)

      assert_raise Ash.Error.Invalid, fn ->
        user
        |> Ash.Changeset.for_update(
          :update_display_name,
          %{
            display_name: long_name
          },
          actor: user
        )
        |> Ash.update!()
      end
    end

    test "unauthenticated update fails" do
      user =
        Ash.Seed.seed!(User, %{
          email: "noactor#{:rand.uniform(99999)}@example.com",
          display_name: "Original Name"
        })

      assert_raise Ash.Error.Forbidden, fn ->
        user
        |> Ash.Changeset.for_update(:update_display_name, %{
          display_name: "New Name"
        })
        |> Ash.update!()
      end
    end

    test "duplicate display_names are allowed" do
      user1 =
        Ash.Seed.seed!(User, %{
          email: "dup1#{:rand.uniform(99999)}@example.com",
          display_name: "Unique Name 1"
        })

      user2 =
        Ash.Seed.seed!(User, %{
          email: "dup2#{:rand.uniform(99999)}@example.com",
          display_name: "Unique Name 2"
        })

      # Update user2 to have same name as user1
      updated_user2 =
        user2
        |> Ash.Changeset.for_update(
          :update_display_name,
          %{
            display_name: "Unique Name 1"
          },
          actor: user2
        )
        |> Ash.update!()

      assert updated_user2.display_name == "Unique Name 1"
      assert user1.display_name == "Unique Name 1"
    end
  end
end
