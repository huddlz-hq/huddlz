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

  describe "create_pending action (eager upload)" do
    test "any authenticated user can create a pending image" do
      user =
        Ash.Seed.seed!(User, %{
          email: "pending-user@example.com",
          display_name: "Pending User",
          role: :user
        })

      attrs = %{
        filename: "pending.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/group_images/pending/test-uuid.jpg",
        thumbnail_path: "/uploads/group_images/pending/test-uuid_thumb.jpg"
      }

      assert {:ok, pending_image} = Communities.create_pending_group_image(attrs, actor: user)
      assert pending_image.filename == "pending.jpg"
      assert pending_image.group_id == nil
    end

    test "pending images have nil group_id" do
      user =
        Ash.Seed.seed!(User, %{
          email: "pending-nil-group@example.com",
          display_name: "Pending Nil Group",
          role: :user
        })

      {:ok, pending_image} =
        Communities.create_pending_group_image(
          %{
            filename: "no-group.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/pending/no-group.jpg"
          },
          actor: user
        )

      assert is_nil(pending_image.group_id)
    end

    test "pending images are excluded from get_current_for_group" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-pending-exclude@example.com",
          display_name: "Pending Exclude Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Pending Exclude",
          slug: "test-group-pending-exclude",
          is_public: true,
          owner_id: owner.id
        })

      # Create a pending image (not assigned to the group)
      {:ok, _pending} =
        Communities.create_pending_group_image(
          %{
            filename: "pending.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/pending/pending.jpg"
          },
          actor: owner
        )

      # Should not find any current image for the group
      assert {:error, %Ash.Error.Invalid{}} =
               Communities.get_current_group_image(group.id, actor: owner)
    end
  end

  describe "assign_to_group action" do
    test "group owner can assign a pending image to their group" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-assign@example.com",
          display_name: "Assign Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Assign",
          slug: "test-group-assign",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_group_image(
          %{
            filename: "to-assign.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/pending/to-assign.jpg"
          },
          actor: owner
        )

      assert is_nil(pending_image.group_id)

      {:ok, assigned_image} =
        Communities.assign_group_image_to_group(pending_image, group.id, actor: owner)

      assert assigned_image.group_id == group.id
    end

    test "non-owner cannot assign image to group they don't own" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-assign-block@example.com",
          display_name: "Assign Block Owner",
          role: :user
        })

      other_user =
        Ash.Seed.seed!(User, %{
          email: "other-assign-block@example.com",
          display_name: "Other Assign Block",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Assign Block",
          slug: "test-group-assign-block",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_group_image(
          %{
            filename: "blocked.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/pending/blocked.jpg"
          },
          actor: other_user
        )

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.assign_group_image_to_group!(pending_image, group.id, actor: other_user)
      end
    end

    test "cannot assign an already assigned image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-double-assign@example.com",
          display_name: "Double Assign Owner",
          role: :user
        })

      group1 =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Double Assign 1",
          slug: "test-group-double-assign-1",
          is_public: true,
          owner_id: owner.id
        })

      group2 =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Double Assign 2",
          slug: "test-group-double-assign-2",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_group_image(
          %{
            filename: "double.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/pending/double.jpg"
          },
          actor: owner
        )

      # First assignment succeeds
      {:ok, assigned_image} =
        Communities.assign_group_image_to_group(pending_image, group1.id, actor: owner)

      # Second assignment fails
      assert {:error, %Ash.Error.Invalid{}} =
               Communities.assign_group_image_to_group(assigned_image, group2.id, actor: owner)
    end
  end

  describe "orphaned_pending action" do
    test "finds pending images older than 24 hours" do
      user =
        Ash.Seed.seed!(User, %{
          email: "orphan-test@example.com",
          display_name: "Orphan Test",
          role: :user
        })

      # Create a pending image and manually backdate it
      {:ok, pending_image} =
        Communities.create_pending_group_image(
          %{
            filename: "orphaned.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/pending/orphaned-#{System.unique_integer()}.jpg"
          },
          actor: user
        )

      # Backdate the image to 25 hours ago
      old_time = DateTime.add(DateTime.utc_now(), -25, :hour)
      {:ok, uuid_binary} = Ecto.UUID.dump(pending_image.id)

      Huddlz.Repo.query!(
        "UPDATE group_images SET inserted_at = $1 WHERE id = $2",
        [old_time, uuid_binary]
      )

      # Query for orphaned images (uses Ash without actor for Oban context)
      orphaned =
        GroupImage
        |> Ash.Query.for_read(:orphaned_pending)
        |> Ash.read!(page: [limit: 100])

      assert Enum.any?(orphaned.results, fn img -> img.id == pending_image.id end)
    end

    test "does not find pending images less than 24 hours old" do
      user =
        Ash.Seed.seed!(User, %{
          email: "recent-orphan@example.com",
          display_name: "Recent Orphan",
          role: :user
        })

      {:ok, pending_image} =
        Communities.create_pending_group_image(
          %{
            filename: "recent.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/pending/recent-#{System.unique_integer()}.jpg"
          },
          actor: user
        )

      orphaned =
        GroupImage
        |> Ash.Query.for_read(:orphaned_pending)
        |> Ash.read!(page: [limit: 100])

      refute Enum.any?(orphaned.results, fn img -> img.id == pending_image.id end)
    end

    test "does not find assigned images even if old" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "assigned-old@example.com",
          display_name: "Assigned Old",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Assigned Old",
          slug: "test-group-assigned-old",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_group_image(
          %{
            filename: "assigned-old.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path:
              "/uploads/group_images/pending/assigned-old-#{System.unique_integer()}.jpg"
          },
          actor: owner
        )

      # Assign to group
      {:ok, assigned_image} =
        Communities.assign_group_image_to_group(pending_image, group.id, actor: owner)

      # Backdate the image
      old_time = DateTime.add(DateTime.utc_now(), -25, :hour)
      {:ok, uuid_binary} = Ecto.UUID.dump(assigned_image.id)

      Huddlz.Repo.query!(
        "UPDATE group_images SET inserted_at = $1 WHERE id = $2",
        [old_time, uuid_binary]
      )

      orphaned =
        GroupImage
        |> Ash.Query.for_read(:orphaned_pending)
        |> Ash.read!(page: [limit: 100])

      refute Enum.any?(orphaned.results, fn img -> img.id == assigned_image.id end)
    end
  end
end
