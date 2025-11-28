defmodule Huddlz.Accounts.ProfilePictureTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User

  describe "create profile picture" do
    test "users can create their own profile picture" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-profile-pic@example.com",
          display_name: "Profile Pic User",
          role: :user
        })

      attrs = %{
        filename: "avatar.jpg",
        content_type: "image/jpeg",
        size_bytes: 12_345,
        storage_path: "/uploads/profile_pictures/#{user.id}/avatar.jpg",
        user_id: user.id
      }

      assert {:ok, profile_picture} = Accounts.create_profile_picture(attrs, actor: user)
      assert profile_picture.filename == "avatar.jpg"
      assert profile_picture.content_type == "image/jpeg"
      assert profile_picture.size_bytes == 12_345
      assert profile_picture.user_id == user.id
    end

    test "users cannot create profile pictures for other users" do
      user1 =
        Ash.Seed.seed!(User, %{
          email: "user1-profile@example.com",
          display_name: "User One",
          role: :user
        })

      user2 =
        Ash.Seed.seed!(User, %{
          email: "user2-profile@example.com",
          display_name: "User Two",
          role: :user
        })

      attrs = %{
        filename: "avatar.jpg",
        content_type: "image/jpeg",
        size_bytes: 12_345,
        storage_path: "/uploads/profile_pictures/#{user2.id}/avatar.jpg",
        user_id: user2.id
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.create_profile_picture!(attrs, actor: user1)
      end
    end

    test "admins can create profile pictures for any user" do
      admin =
        Ash.Seed.seed!(User, %{
          email: "admin-profile@example.com",
          display_name: "Admin User",
          role: :admin
        })

      user =
        Ash.Seed.seed!(User, %{
          email: "user-for-admin@example.com",
          display_name: "Regular User",
          role: :user
        })

      attrs = %{
        filename: "avatar.jpg",
        content_type: "image/jpeg",
        size_bytes: 12_345,
        storage_path: "/uploads/profile_pictures/#{user.id}/avatar.jpg",
        user_id: user.id
      }

      assert {:ok, profile_picture} = Accounts.create_profile_picture(attrs, actor: admin)
      assert profile_picture.user_id == user.id
    end
  end

  describe "get current profile picture" do
    test "returns the most recent profile picture for a user" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-current@example.com",
          display_name: "Current User",
          role: :user
        })

      # Create first profile picture
      {:ok, _pic1} =
        Accounts.create_profile_picture(
          %{
            filename: "first.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user.id}/first.jpg",
            user_id: user.id
          },
          actor: user
        )

      # Small delay to ensure different timestamps
      Process.sleep(10)

      # Create second profile picture (most recent)
      {:ok, pic2} =
        Accounts.create_profile_picture(
          %{
            filename: "second.jpg",
            content_type: "image/jpeg",
            size_bytes: 2000,
            storage_path: "/uploads/profile_pictures/#{user.id}/second.jpg",
            user_id: user.id
          },
          actor: user
        )

      assert {:ok, current} = Accounts.get_current_profile_picture(user.id, actor: user)
      assert current.id == pic2.id
      assert current.filename == "second.jpg"
    end

    test "returns error when user has no profile picture" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-nopic@example.com",
          display_name: "No Pic User",
          role: :user
        })

      # get? true actions return NotFound error when nothing is found
      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.get_current_profile_picture(user.id, actor: user)
    end
  end

  describe "list profile pictures" do
    test "lists all profile pictures for a user" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-list@example.com",
          display_name: "List User",
          role: :user
        })

      # Create multiple profile pictures
      for i <- 1..3 do
        Accounts.create_profile_picture!(
          %{
            filename: "avatar#{i}.jpg",
            content_type: "image/jpeg",
            size_bytes: i * 1000,
            storage_path: "/uploads/profile_pictures/#{user.id}/avatar#{i}.jpg",
            user_id: user.id
          },
          actor: user
        )
      end

      assert {:ok, pictures} = Accounts.list_profile_pictures(user.id, actor: user)
      assert length(pictures) == 3
    end
  end

  describe "delete profile picture" do
    test "users can delete their own profile pictures" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-delete@example.com",
          display_name: "Delete User",
          role: :user
        })

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "todelete.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user.id}/todelete.jpg",
            user_id: user.id
          },
          actor: user
        )

      assert :ok = Accounts.delete_profile_picture(picture, actor: user)
      # After deletion, get_current returns NotFound
      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.get_current_profile_picture(user.id, actor: user)
    end

    test "users cannot delete other users' profile pictures" do
      user1 =
        Ash.Seed.seed!(User, %{
          email: "user1-delete@example.com",
          display_name: "User One",
          role: :user
        })

      user2 =
        Ash.Seed.seed!(User, %{
          email: "user2-delete@example.com",
          display_name: "User Two",
          role: :user
        })

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "user2pic.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user2.id}/user2pic.jpg",
            user_id: user2.id
          },
          actor: user2
        )

      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.delete_profile_picture!(picture, actor: user1)
      end
    end
  end

  describe "current_profile_picture_url calculation" do
    test "returns storage path of most recent profile picture" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-calc@example.com",
          display_name: "Calc User",
          role: :user
        })

      storage_path = "/uploads/profile_pictures/#{user.id}/latest.jpg"

      {:ok, _picture} =
        Accounts.create_profile_picture(
          %{
            filename: "latest.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: storage_path,
            user_id: user.id
          },
          actor: user
        )

      {:ok, loaded_user} = Ash.load(user, [:current_profile_picture_url], actor: user)
      assert loaded_user.current_profile_picture_url == storage_path
    end

    test "returns nil when user has no profile picture" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-nocal@example.com",
          display_name: "No Calc User",
          role: :user
        })

      {:ok, loaded_user} = Ash.load(user, [:current_profile_picture_url], actor: user)
      assert loaded_user.current_profile_picture_url == nil
    end
  end
end
