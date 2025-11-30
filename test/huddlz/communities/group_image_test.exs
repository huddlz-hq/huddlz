defmodule Huddlz.Communities.GroupImageTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupImage

  describe "create group image" do
    test "group owner can create a group image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-group-image@example.com",
          display_name: "Group Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group for Images",
          slug: "test-group-images",
          is_public: true,
          owner_id: owner.id
        })

      attrs = %{
        filename: "banner.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/group_images/#{group.id}/banner.jpg",
        thumbnail_path: "/uploads/group_images/#{group.id}/banner_thumb.jpg",
        group_id: group.id
      }

      assert {:ok, group_image} = Communities.create_group_image(attrs, actor: owner)
      assert group_image.filename == "banner.jpg"
      assert group_image.content_type == "image/jpeg"
      assert group_image.size_bytes == 50_000
      assert group_image.group_id == group.id
    end

    test "non-owner cannot create group image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-no-access@example.com",
          display_name: "Group Owner",
          role: :user
        })

      other_user =
        Ash.Seed.seed!(User, %{
          email: "other-user@example.com",
          display_name: "Other User",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group No Access",
          slug: "test-group-no-access",
          is_public: true,
          owner_id: owner.id
        })

      attrs = %{
        filename: "banner.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/group_images/#{group.id}/banner.jpg",
        group_id: group.id
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.create_group_image!(attrs, actor: other_user)
      end
    end

    test "admin can create group image for any group" do
      admin =
        Ash.Seed.seed!(User, %{
          email: "admin-group-image@example.com",
          display_name: "Admin User",
          role: :admin
        })

      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-for-admin@example.com",
          display_name: "Group Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Admin",
          slug: "test-group-admin",
          is_public: true,
          owner_id: owner.id
        })

      attrs = %{
        filename: "admin-banner.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/group_images/#{group.id}/admin-banner.jpg",
        group_id: group.id
      }

      assert {:ok, group_image} = Communities.create_group_image(attrs, actor: admin)
      assert group_image.group_id == group.id
    end
  end

  describe "get current group image" do
    test "returns the most recent image for a group" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-current@example.com",
          display_name: "Current Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Current",
          slug: "test-group-current",
          is_public: true,
          owner_id: owner.id
        })

      # Create first image
      {:ok, _img1} =
        Communities.create_group_image(
          %{
            filename: "first.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/first.jpg",
            group_id: group.id
          },
          actor: owner
        )

      # Small delay to ensure different timestamps
      Process.sleep(10)

      # Create second image (most recent)
      {:ok, img2} =
        Communities.create_group_image(
          %{
            filename: "second.jpg",
            content_type: "image/jpeg",
            size_bytes: 2000,
            storage_path: "/uploads/group_images/#{group.id}/second.jpg",
            group_id: group.id
          },
          actor: owner
        )

      assert {:ok, current} = Communities.get_current_group_image(group.id, actor: owner)
      assert current.id == img2.id
      assert current.filename == "second.jpg"
    end

    test "returns error when group has no image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-noimage@example.com",
          display_name: "No Image Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group No Image",
          slug: "test-group-no-image",
          is_public: true,
          owner_id: owner.id
        })

      assert {:error, %Ash.Error.Invalid{}} =
               Communities.get_current_group_image(group.id, actor: owner)
    end
  end

  describe "list group images" do
    test "lists all images for a group" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-list@example.com",
          display_name: "List Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group List",
          slug: "test-group-list",
          is_public: true,
          owner_id: owner.id
        })

      for i <- 1..3 do
        Communities.create_group_image!(
          %{
            filename: "image#{i}.jpg",
            content_type: "image/jpeg",
            size_bytes: i * 1000,
            storage_path: "/uploads/group_images/#{group.id}/image#{i}.jpg",
            group_id: group.id
          },
          actor: owner
        )
      end

      assert {:ok, images} = Communities.list_group_images(group.id, actor: owner)
      assert length(images) == 3
    end
  end

  describe "soft_delete action" do
    test "soft-delete sets deleted_at timestamp" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-softdelete@example.com",
          display_name: "Soft Delete Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Soft Delete",
          slug: "test-group-softdelete",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, image} =
        Communities.create_group_image(
          %{
            filename: "to-soft-delete.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/to-soft-delete.jpg",
            group_id: group.id
          },
          actor: owner
        )

      assert is_nil(image.deleted_at)

      {:ok, soft_deleted} = Communities.soft_delete_group_image(image, actor: owner)

      assert not is_nil(soft_deleted.deleted_at)
    end

    test "soft-deleted images are excluded from current image queries" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-softdelete-exclude@example.com",
          display_name: "Soft Delete Exclude Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Soft Delete Exclude",
          slug: "test-group-softdelete-exclude",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, image} =
        Communities.create_group_image(
          %{
            filename: "will-be-excluded.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/will-be-excluded.jpg",
            group_id: group.id
          },
          actor: owner
        )

      # Before soft-delete, image is current
      {:ok, current} = Communities.get_current_group_image(group.id, actor: owner)
      assert current.id == image.id

      # After soft-delete, image is excluded
      {:ok, _} = Communities.soft_delete_group_image(image, actor: owner)

      assert {:error, %Ash.Error.Invalid{}} =
               Communities.get_current_group_image(group.id, actor: owner)
    end

    test "soft-delete enqueues cleanup job" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-oban-enqueue@example.com",
          display_name: "Oban Enqueue Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Oban",
          slug: "test-group-oban",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, image} =
        Communities.create_group_image(
          %{
            filename: "oban-test.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/oban-test.jpg",
            group_id: group.id
          },
          actor: owner
        )

      {:ok, _} = Communities.soft_delete_group_image(image, actor: owner)

      # Assert that a job was enqueued in the group_image_cleanup queue
      assert_enqueued(
        worker: Huddlz.Workers.GroupImageCleanup,
        queue: :group_image_cleanup
      )
    end

    test "non-owner cannot soft-delete group images" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner1-softdelete@example.com",
          display_name: "Owner One Soft",
          role: :user
        })

      other_user =
        Ash.Seed.seed!(User, %{
          email: "other-softdelete@example.com",
          display_name: "Other Soft",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Other Soft Delete",
          slug: "test-group-other-softdelete",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, image} =
        Communities.create_group_image(
          %{
            filename: "owner-pic.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/owner-pic.jpg",
            group_id: group.id
          },
          actor: owner
        )

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.soft_delete_group_image!(image, actor: other_user)
      end
    end
  end

  describe "hard_delete action (background cleanup)" do
    test "hard_delete removes record from database" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-harddelete@example.com",
          display_name: "Hard Delete Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Hard Delete",
          slug: "test-group-harddelete",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, image} =
        Communities.create_group_image(
          %{
            filename: "to-hard-delete.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/to-hard-delete.jpg",
            group_id: group.id
          },
          actor: owner
        )

      # Soft-delete first (simulates real flow)
      {:ok, soft_deleted} = Communities.soft_delete_group_image(image, actor: owner)

      # Hard delete (as background job would do - no actor)
      assert :ok = Ash.destroy(soft_deleted, action: :hard_delete)

      # Record should be completely gone
      assert {:error, _} = Ash.get(GroupImage, image.id, action: :read)
    end

    test "running the cleanup job deletes soft-deleted image from database" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-cleanup-job@example.com",
          display_name: "Cleanup Job Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Cleanup Job",
          slug: "test-group-cleanup-job",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, image} =
        Communities.create_group_image(
          %{
            filename: "cleanup-job-test.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/cleanup-job-test.jpg",
            group_id: group.id
          },
          actor: owner
        )

      # Soft-delete enqueues the job
      {:ok, _} = Communities.soft_delete_group_image(image, actor: owner)

      # Drain the queue to run the job
      Oban.drain_queue(queue: :group_image_cleanup)

      # Record should be gone from database
      assert {:error, _} = Ash.get(GroupImage, image.id, action: :read)
    end
  end

  describe "current_image_url aggregate" do
    test "returns thumbnail path of most recent group image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-aggregate@example.com",
          display_name: "Aggregate Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Aggregate",
          slug: "test-group-aggregate",
          is_public: true,
          owner_id: owner.id
        })

      thumbnail_path = "/uploads/group_images/#{group.id}/latest_thumb.jpg"

      {:ok, _image} =
        Communities.create_group_image(
          %{
            filename: "latest.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/latest.jpg",
            thumbnail_path: thumbnail_path,
            group_id: group.id
          },
          actor: owner
        )

      {:ok, loaded_group} = Ash.load(group, [:current_image_url], actor: owner)
      assert loaded_group.current_image_url == thumbnail_path
    end

    test "returns nil when group has no image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-aggregate-none@example.com",
          display_name: "Aggregate None Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Aggregate None",
          slug: "test-group-aggregate-none",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, loaded_group} = Ash.load(group, [:current_image_url], actor: owner)
      assert loaded_group.current_image_url == nil
    end

    test "excludes soft-deleted images from aggregate" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-aggregate-deleted@example.com",
          display_name: "Aggregate Deleted Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Aggregate Deleted",
          slug: "test-group-aggregate-deleted",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, image} =
        Communities.create_group_image(
          %{
            filename: "to-delete.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/to-delete.jpg",
            thumbnail_path: "/uploads/group_images/#{group.id}/to-delete_thumb.jpg",
            group_id: group.id
          },
          actor: owner
        )

      # Before soft-delete
      {:ok, loaded_group} = Ash.load(group, [:current_image_url], actor: owner)
      assert loaded_group.current_image_url != nil

      # Soft-delete
      {:ok, _} = Communities.soft_delete_group_image(image, actor: owner)

      # After soft-delete
      {:ok, reloaded_group} = Ash.load(group, [:current_image_url], actor: owner)
      assert reloaded_group.current_image_url == nil
    end
  end
end
