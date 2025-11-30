defmodule Huddlz.Accounts.ProfilePictureTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Accounts
  alias Huddlz.Accounts.ProfilePicture
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
    test "returns thumbnail path of most recent profile picture" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-calc@example.com",
          display_name: "Calc User",
          role: :user
        })

      storage_path = "/uploads/profile_pictures/#{user.id}/latest.jpg"
      thumbnail_path = "/uploads/profile_pictures/#{user.id}/latest_thumb.jpg"

      {:ok, _picture} =
        Accounts.create_profile_picture(
          %{
            filename: "latest.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: storage_path,
            thumbnail_path: thumbnail_path,
            user_id: user.id
          },
          actor: user
        )

      {:ok, loaded_user} = Ash.load(user, [:current_profile_picture_url], actor: user)
      assert loaded_user.current_profile_picture_url == thumbnail_path
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

  describe "soft_delete action" do
    test "soft-delete sets deleted_at timestamp" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-softdelete@example.com",
          display_name: "Soft Delete User",
          role: :user
        })

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "to-soft-delete.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user.id}/to-soft-delete.jpg",
            user_id: user.id
          },
          actor: user
        )

      assert is_nil(picture.deleted_at)

      {:ok, soft_deleted} = Accounts.soft_delete_profile_picture(picture, actor: user)

      assert not is_nil(soft_deleted.deleted_at)
    end

    test "soft-deleted pictures are excluded from current picture queries" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-softdelete-exclude@example.com",
          display_name: "Soft Delete Exclude User",
          role: :user
        })

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "will-be-excluded.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user.id}/will-be-excluded.jpg",
            user_id: user.id
          },
          actor: user
        )

      # Before soft-delete, picture is current
      {:ok, current} = Accounts.get_current_profile_picture(user.id, actor: user)
      assert current.id == picture.id

      # After soft-delete, picture is excluded
      {:ok, _} = Accounts.soft_delete_profile_picture(picture, actor: user)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.get_current_profile_picture(user.id, actor: user)
    end

    test "soft-delete enqueues cleanup job" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-oban-enqueue@example.com",
          display_name: "Oban Enqueue User",
          role: :user
        })

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "oban-test.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user.id}/oban-test.jpg",
            user_id: user.id
          },
          actor: user
        )

      {:ok, _} = Accounts.soft_delete_profile_picture(picture, actor: user)

      # Assert that a job was enqueued in the profile_picture_cleanup queue
      assert_enqueued(
        worker: Huddlz.Workers.ProfilePictureCleanup,
        queue: :profile_picture_cleanup
      )
    end

    test "users cannot soft-delete other users' profile pictures" do
      user1 =
        Ash.Seed.seed!(User, %{
          email: "user1-softdelete@example.com",
          display_name: "User One Soft",
          role: :user
        })

      user2 =
        Ash.Seed.seed!(User, %{
          email: "user2-softdelete@example.com",
          display_name: "User Two Soft",
          role: :user
        })

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "user2-pic.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user2.id}/user2-pic.jpg",
            user_id: user2.id
          },
          actor: user2
        )

      assert_raise Ash.Error.Forbidden, fn ->
        Accounts.soft_delete_profile_picture!(picture, actor: user1)
      end
    end
  end

  describe "hard_delete action (background cleanup)" do
    test "hard_delete removes record from database" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-harddelete@example.com",
          display_name: "Hard Delete User",
          role: :user
        })

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "to-hard-delete.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/profile_pictures/#{user.id}/to-hard-delete.jpg",
            user_id: user.id
          },
          actor: user
        )

      # Soft-delete first (simulates real flow)
      {:ok, soft_deleted} = Accounts.soft_delete_profile_picture(picture, actor: user)

      # Hard delete (as background job would do - no actor)
      assert :ok = Ash.destroy(soft_deleted, action: :hard_delete)

      # Record should be completely gone
      assert {:error, _} = Ash.get(ProfilePicture, picture.id, action: :read)
    end

    test "running the cleanup job deletes soft-deleted picture from storage and database" do
      user =
        Ash.Seed.seed!(User, %{
          email: "user-cleanup-job@example.com",
          display_name: "Cleanup Job User",
          role: :user
        })

      storage_path = "/uploads/profile_pictures/#{user.id}/cleanup-job-test.jpg"

      {:ok, picture} =
        Accounts.create_profile_picture(
          %{
            filename: "cleanup-job-test.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: storage_path,
            user_id: user.id
          },
          actor: user
        )

      # Soft-delete enqueues the job
      {:ok, _} = Accounts.soft_delete_profile_picture(picture, actor: user)

      # Drain the queue to run the job
      # This will execute the hard_delete action which deletes from storage
      Oban.drain_queue(queue: :profile_picture_cleanup)

      # Record should be gone from database
      assert {:error, _} = Ash.get(ProfilePicture, picture.id, action: :read)
    end
  end
end
