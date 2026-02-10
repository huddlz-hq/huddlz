defmodule Huddlz.Communities.HuddlImageTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlImage

  describe "create huddl image" do
    test "group owner can create a huddl image" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: "organizer", actor: owner)
      )

      huddl =
        generate(
          past_huddl(
            group_id: group.id,
            creator_id: organizer.id,
            event_type: :virtual,
            virtual_link: "https://example.com",
            physical_location: nil
          )
        )

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
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: "member", actor: owner))

      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      admin = generate(user(role: :admin))
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      assert {:error, %Ash.Error.Invalid{}} =
               Communities.get_current_huddl_image(huddl.id, actor: owner)
    end
  end

  describe "soft_delete action" do
    test "soft-delete sets deleted_at timestamp" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, loaded_huddl} = Ash.load(huddl, [:current_image_url], actor: owner)
      assert loaded_huddl.current_image_url == nil
    end
  end

  describe "display_image_url calculation (fallback chain)" do
    test "returns huddl image when available" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

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

      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

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

      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, loaded_huddl} = Ash.load(huddl, [:display_image_url], actor: owner)
      assert loaded_huddl.display_image_url == group_thumb
    end

    test "returns nil when neither huddl nor group has image" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, loaded_huddl} = Ash.load(huddl, [:display_image_url], actor: owner)
      assert loaded_huddl.display_image_url == nil
    end
  end

  describe "create_pending action (group member only)" do
    test "group member can create a pending image" do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: "member", actor: owner))

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
      owner = generate(user(role: :user))
      non_member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: "member", actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl1 = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      huddl2 = generate(past_huddl(group_id: group.id, creator_id: owner.id))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

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
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

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
