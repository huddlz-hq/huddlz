defmodule Huddlz.Communities.HuddlImageTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlImage

  describe "create huddl image" do
    test "group owner can create a huddl image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-huddl-image@example.com",
          display_name: "Huddl Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group for Huddl Images",
          slug: "test-group-huddl-images",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Test Huddl with Image",
          description: "A huddl to test images",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Test Location",
          group_id: group.id,
          creator_id: owner.id
        })

      attrs = %{
        filename: "huddl-banner.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_images/#{huddl.id}/banner.jpg",
        thumbnail_path: "/uploads/huddl_images/#{huddl.id}/banner_thumb.jpg",
        huddl_id: huddl.id
      }

      assert {:ok, huddl_image} = Communities.create_huddl_image(attrs, actor: owner)
      assert huddl_image.filename == "huddl-banner.jpg"
      assert huddl_image.content_type == "image/jpeg"
      assert huddl_image.size_bytes == 50_000
      assert huddl_image.huddl_id == huddl.id
    end

    test "organizer can create huddl image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-organizer-img@example.com",
          display_name: "Owner",
          role: :user
        })

      organizer =
        Ash.Seed.seed!(User, %{
          email: "organizer-img@example.com",
          display_name: "Organizer",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Organizer Image",
          slug: "test-group-organizer-image",
          is_public: true,
          owner_id: owner.id
        })

      Ash.Seed.seed!(GroupMember, %{
        group_id: group.id,
        user_id: organizer.id,
        role: :organizer
      })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Organizer Huddl Image",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :virtual,
          virtual_link: "https://example.com",
          group_id: group.id,
          creator_id: organizer.id
        })

      attrs = %{
        filename: "organizer.jpg",
        content_type: "image/jpeg",
        size_bytes: 1000,
        storage_path: "/uploads/huddl_images/#{huddl.id}/organizer.jpg",
        huddl_id: huddl.id
      }

      assert {:ok, huddl_image} = Communities.create_huddl_image(attrs, actor: organizer)
      assert huddl_image.huddl_id == huddl.id
    end

    test "regular member cannot create huddl image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-member-block@example.com",
          display_name: "Owner",
          role: :user
        })

      member =
        Ash.Seed.seed!(User, %{
          email: "member-block@example.com",
          display_name: "Member",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Member Block",
          slug: "test-group-member-block",
          is_public: true,
          owner_id: owner.id
        })

      Ash.Seed.seed!(GroupMember, %{
        group_id: group.id,
        user_id: member.id,
        role: :member
      })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Member Block Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      attrs = %{
        filename: "member.jpg",
        content_type: "image/jpeg",
        size_bytes: 1000,
        storage_path: "/uploads/huddl_images/#{huddl.id}/member.jpg",
        huddl_id: huddl.id
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.create_huddl_image!(attrs, actor: member)
      end
    end

    test "admin can create huddl image for any huddl" do
      admin =
        Ash.Seed.seed!(User, %{
          email: "admin-huddl-image@example.com",
          display_name: "Admin User",
          role: :admin
        })

      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-for-admin-huddl@example.com",
          display_name: "Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Admin Huddl",
          slug: "test-group-admin-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Admin Huddl Image",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      attrs = %{
        filename: "admin-banner.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_images/#{huddl.id}/admin-banner.jpg",
        huddl_id: huddl.id
      }

      assert {:ok, huddl_image} = Communities.create_huddl_image(attrs, actor: admin)
      assert huddl_image.huddl_id == huddl.id
    end
  end

  describe "get current huddl image" do
    test "returns the most recent image for a huddl" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-current-huddl@example.com",
          display_name: "Current Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Current Huddl",
          slug: "test-group-current-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Current Image Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      # Create first image
      {:ok, _img1} =
        Communities.create_huddl_image(
          %{
            filename: "first.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/#{huddl.id}/first.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      Process.sleep(10)

      # Create second image (most recent)
      {:ok, img2} =
        Communities.create_huddl_image(
          %{
            filename: "second.jpg",
            content_type: "image/jpeg",
            size_bytes: 2000,
            storage_path: "/uploads/huddl_images/#{huddl.id}/second.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      assert {:ok, current} = Communities.get_current_huddl_image(huddl.id, actor: owner)
      assert current.id == img2.id
      assert current.filename == "second.jpg"
    end

    test "returns error when huddl has no image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-noimage-huddl@example.com",
          display_name: "No Image Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group No Image Huddl",
          slug: "test-group-no-image-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "No Image Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      assert {:error, %Ash.Error.Invalid{}} =
               Communities.get_current_huddl_image(huddl.id, actor: owner)
    end
  end

  describe "soft_delete action" do
    test "soft-delete sets deleted_at timestamp" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-softdelete-huddl@example.com",
          display_name: "Soft Delete Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Soft Delete Huddl",
          slug: "test-group-softdelete-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Soft Delete Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, image} =
        Communities.create_huddl_image(
          %{
            filename: "to-soft-delete.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/#{huddl.id}/to-soft-delete.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      assert is_nil(image.deleted_at)

      {:ok, soft_deleted} = Communities.soft_delete_huddl_image(image, actor: owner)

      assert not is_nil(soft_deleted.deleted_at)
    end

    test "soft-delete enqueues cleanup job" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-oban-huddl@example.com",
          display_name: "Oban Huddl Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Oban Huddl",
          slug: "test-group-oban-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Oban Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, image} =
        Communities.create_huddl_image(
          %{
            filename: "oban-test.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/#{huddl.id}/oban-test.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      {:ok, _} = Communities.soft_delete_huddl_image(image, actor: owner)

      assert_enqueued(
        worker: Huddlz.Workers.HuddlImageCleanup,
        queue: :huddl_image_cleanup
      )
    end
  end

  describe "current_image_url aggregate" do
    test "returns thumbnail path of most recent huddl image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-aggregate-huddl@example.com",
          display_name: "Aggregate Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Aggregate Huddl",
          slug: "test-group-aggregate-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Aggregate Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      thumbnail_path = "/uploads/huddl_images/#{huddl.id}/latest_thumb.jpg"

      {:ok, _image} =
        Communities.create_huddl_image(
          %{
            filename: "latest.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/#{huddl.id}/latest.jpg",
            thumbnail_path: thumbnail_path,
            huddl_id: huddl.id
          },
          actor: owner
        )

      {:ok, loaded_huddl} = Ash.load(huddl, [:current_image_url], actor: owner)
      assert loaded_huddl.current_image_url == thumbnail_path
    end

    test "returns nil when huddl has no image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-aggregate-none-huddl@example.com",
          display_name: "Aggregate None Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Aggregate None Huddl",
          slug: "test-group-aggregate-none-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "No Image Aggregate Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, loaded_huddl} = Ash.load(huddl, [:current_image_url], actor: owner)
      assert loaded_huddl.current_image_url == nil
    end
  end

  describe "display_image_url calculation (fallback chain)" do
    test "returns huddl image when available" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-display-huddl@example.com",
          display_name: "Display Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Display Huddl",
          slug: "test-group-display-huddl",
          is_public: true,
          owner_id: owner.id
        })

      # Add group image
      Communities.create_group_image!(
        %{
          filename: "group.jpg",
          content_type: "image/jpeg",
          size_bytes: 1000,
          storage_path: "/uploads/group_images/#{group.id}/group.jpg",
          thumbnail_path: "/uploads/group_images/#{group.id}/group_thumb.jpg",
          group_id: group.id
        },
        actor: owner
      )

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Display Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      huddl_thumb = "/uploads/huddl_images/#{huddl.id}/huddl_thumb.jpg"

      {:ok, _} =
        Communities.create_huddl_image(
          %{
            filename: "huddl.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/#{huddl.id}/huddl.jpg",
            thumbnail_path: huddl_thumb,
            huddl_id: huddl.id
          },
          actor: owner
        )

      {:ok, loaded_huddl} = Ash.load(huddl, [:display_image_url], actor: owner)
      assert loaded_huddl.display_image_url == huddl_thumb
    end

    test "falls back to group image when huddl has no image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-fallback-group@example.com",
          display_name: "Fallback Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Fallback",
          slug: "test-group-fallback",
          is_public: true,
          owner_id: owner.id
        })

      group_thumb = "/uploads/group_images/#{group.id}/group_thumb.jpg"

      Communities.create_group_image!(
        %{
          filename: "group.jpg",
          content_type: "image/jpeg",
          size_bytes: 1000,
          storage_path: "/uploads/group_images/#{group.id}/group.jpg",
          thumbnail_path: group_thumb,
          group_id: group.id
        },
        actor: owner
      )

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Fallback Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, loaded_huddl} = Ash.load(huddl, [:display_image_url], actor: owner)
      assert loaded_huddl.display_image_url == group_thumb
    end

    test "returns nil when neither huddl nor group has image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-no-fallback@example.com",
          display_name: "No Fallback Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group No Fallback",
          slug: "test-group-no-fallback",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "No Fallback Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, loaded_huddl} = Ash.load(huddl, [:display_image_url], actor: owner)
      assert loaded_huddl.display_image_url == nil
    end
  end

  describe "create_pending action (group member only)" do
    test "group member can create a pending image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-pending-huddl@example.com",
          display_name: "Owner",
          role: :user
        })

      member =
        Ash.Seed.seed!(User, %{
          email: "member-pending-huddl@example.com",
          display_name: "Member",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Pending Huddl",
          slug: "test-group-pending-huddl",
          is_public: true,
          owner_id: owner.id
        })

      Ash.Seed.seed!(GroupMember, %{
        group_id: group.id,
        user_id: member.id,
        role: :member
      })

      attrs = %{
        filename: "pending.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_images/pending/test-uuid.jpg",
        thumbnail_path: "/uploads/huddl_images/pending/test-uuid_thumb.jpg"
      }

      assert {:ok, pending_image} =
               Communities.create_pending_huddl_image(group.id, attrs, actor: member)

      assert pending_image.filename == "pending.jpg"
      assert pending_image.huddl_id == nil
    end

    test "non-member cannot create pending image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-nonmember-pending@example.com",
          display_name: "Owner",
          role: :user
        })

      non_member =
        Ash.Seed.seed!(User, %{
          email: "nonmember-pending@example.com",
          display_name: "Non Member",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Nonmember Pending",
          slug: "test-group-nonmember-pending",
          is_public: true,
          owner_id: owner.id
        })

      attrs = %{
        filename: "blocked.jpg",
        content_type: "image/jpeg",
        size_bytes: 1000,
        storage_path: "/uploads/huddl_images/pending/blocked.jpg"
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.create_pending_huddl_image!(group.id, attrs, actor: non_member)
      end
    end

    test "pending images have nil huddl_id" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-nil-huddl@example.com",
          display_name: "Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Nil Huddl",
          slug: "test-group-nil-huddl",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_huddl_image(
          group.id,
          %{
            filename: "no-huddl.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/pending/no-huddl.jpg"
          },
          actor: owner
        )

      assert is_nil(pending_image.huddl_id)
    end
  end

  describe "assign_to_huddl action" do
    test "group owner can assign a pending image to their huddl" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-assign-huddl@example.com",
          display_name: "Assign Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Assign Huddl",
          slug: "test-group-assign-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Assign Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_huddl_image(
          group.id,
          %{
            filename: "to-assign.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/pending/to-assign.jpg"
          },
          actor: owner
        )

      assert is_nil(pending_image.huddl_id)

      {:ok, assigned_image} =
        Communities.assign_huddl_image_to_huddl(pending_image, huddl.id, actor: owner)

      assert assigned_image.huddl_id == huddl.id
    end

    test "regular member cannot assign image to huddl they don't own" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-assign-block-huddl@example.com",
          display_name: "Owner",
          role: :user
        })

      member =
        Ash.Seed.seed!(User, %{
          email: "member-assign-block@example.com",
          display_name: "Member",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Assign Block Huddl",
          slug: "test-group-assign-block-huddl",
          is_public: true,
          owner_id: owner.id
        })

      Ash.Seed.seed!(GroupMember, %{
        group_id: group.id,
        user_id: member.id,
        role: :member
      })

      huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Assign Block Huddl",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_huddl_image(
          group.id,
          %{
            filename: "blocked.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/pending/blocked.jpg"
          },
          actor: member
        )

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.assign_huddl_image_to_huddl!(pending_image, huddl.id, actor: member)
      end
    end

    test "cannot assign an already assigned image" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "owner-double-assign-huddl@example.com",
          display_name: "Double Assign Owner",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Double Assign Huddl",
          slug: "test-group-double-assign-huddl",
          is_public: true,
          owner_id: owner.id
        })

      huddl1 =
        Ash.Seed.seed!(Huddl, %{
          title: "Double Assign Huddl 1",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere",
          group_id: group.id,
          creator_id: owner.id
        })

      huddl2 =
        Ash.Seed.seed!(Huddl, %{
          title: "Double Assign Huddl 2",
          description: "Test",
          starts_at: DateTime.add(DateTime.utc_now(), 2, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 2, :day) |> DateTime.add(2, :hour),
          event_type: :in_person,
          physical_location: "Somewhere else",
          group_id: group.id,
          creator_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_huddl_image(
          group.id,
          %{
            filename: "double.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/pending/double.jpg"
          },
          actor: owner
        )

      # First assignment succeeds
      {:ok, assigned_image} =
        Communities.assign_huddl_image_to_huddl(pending_image, huddl1.id, actor: owner)

      # Second assignment fails
      assert {:error, %Ash.Error.Invalid{}} =
               Communities.assign_huddl_image_to_huddl(assigned_image, huddl2.id, actor: owner)
    end
  end

  describe "orphaned_pending action" do
    test "finds pending images older than 24 hours" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "orphan-huddl-test@example.com",
          display_name: "Orphan Test",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Orphan Huddl",
          slug: "test-group-orphan-huddl",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_huddl_image(
          group.id,
          %{
            filename: "orphaned.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/pending/orphaned-#{System.unique_integer()}.jpg"
          },
          actor: owner
        )

      # Backdate the image to 25 hours ago
      old_time = DateTime.add(DateTime.utc_now(), -25, :hour)
      {:ok, uuid_binary} = Ecto.UUID.dump(pending_image.id)

      Huddlz.Repo.query!(
        "UPDATE huddl_images SET inserted_at = $1 WHERE id = $2",
        [old_time, uuid_binary]
      )

      # Query for orphaned images
      orphaned =
        HuddlImage
        |> Ash.Query.for_read(:orphaned_pending)
        |> Ash.read!(page: [limit: 100])

      assert Enum.any?(orphaned.results, fn img -> img.id == pending_image.id end)
    end

    test "does not find pending images less than 24 hours old" do
      owner =
        Ash.Seed.seed!(User, %{
          email: "recent-orphan-huddl@example.com",
          display_name: "Recent Orphan",
          role: :user
        })

      group =
        Ash.Seed.seed!(Group, %{
          name: "Test Group Recent Orphan Huddl",
          slug: "test-group-recent-orphan-huddl",
          is_public: true,
          owner_id: owner.id
        })

      {:ok, pending_image} =
        Communities.create_pending_huddl_image(
          group.id,
          %{
            filename: "recent.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_images/pending/recent-#{System.unique_integer()}.jpg"
          },
          actor: owner
        )

      orphaned =
        HuddlImage
        |> Ash.Query.for_read(:orphaned_pending)
        |> Ash.read!(page: [limit: 100])

      refute Enum.any?(orphaned.results, fn img -> img.id == pending_image.id end)
    end
  end
end
