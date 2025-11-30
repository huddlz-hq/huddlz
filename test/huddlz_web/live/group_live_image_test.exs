defmodule HuddlzWeb.GroupLiveImageTest do
  @moduledoc """
  Tests for group image upload functionality in GroupLive.New and GroupLive.Edit.
  """
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Phoenix.LiveViewTest

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupImage

  require Ash.Query

  @test_image_path "test/fixtures/test_image.jpg"

  describe "GroupLive.New - image upload" do
    setup do
      owner = generate(user(role: :user))
      %{owner: owner}
    end

    test "shows image upload area", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      assert has_element?(view, "label", "Group Image")
      assert has_element?(view, "*", "Upload a banner image")
      assert has_element?(view, "*", "Click to upload or drag and drop")
      assert has_element?(view, "*", "JPG, PNG, or WebP (max 5MB)")
    end

    test "creates group without image", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      view
      |> form("#group-form", %{
        "form" => %{
          "name" => "No Image Group",
          "description" => "A group without an image",
          "is_public" => "true"
        }
      })
      |> render_submit()

      # Should redirect to group page
      assert_redirected(view, "/groups/no-image-group")

      # Verify group was created without image
      group =
        Group
        |> Ash.Query.filter(name: "No Image Group")
        |> Ash.read_one!(authorize?: false)
        |> Ash.load!(:current_image_url, authorize?: false)

      assert group.current_image_url == nil
    end

    test "eager upload creates pending image immediately", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      # Upload a file
      file_input(view, "#group-form", :group_image, [
        %{
          name: "test_banner.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("test_banner.jpg")

      # Should show "Image uploaded" confirmation
      html = render(view)
      assert html =~ "Image uploaded"

      # Should have created a pending image record
      pending_count =
        GroupImage
        |> Ash.Query.filter(is_nil(group_id) and is_nil(deleted_at))
        |> Ash.count!(authorize?: false)

      assert pending_count >= 1
    end

    test "form submit assigns pending image to new group", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      # Fill in form
      view
      |> form("#group-form", %{
        "form" => %{
          "name" => "Image Upload Group",
          "description" => "A group with an image"
        }
      })
      |> render_change()

      # Upload a file
      file_input(view, "#group-form", :group_image, [
        %{
          name: "banner.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("banner.jpg")

      # Submit form
      view
      |> form("#group-form", %{
        "form" => %{
          "name" => "Image Upload Group",
          "is_public" => "true"
        }
      })
      |> render_submit()

      # Should redirect
      assert_redirected(view, "/groups/image-upload-group")

      # Verify group has image
      group =
        Group
        |> Ash.Query.filter(name: "Image Upload Group")
        |> Ash.read_one!(authorize?: false)
        |> Ash.load!(:current_image_url, authorize?: false)

      assert group.current_image_url != nil
    end

    test "cancel pending image removes preview", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      # Upload a file
      file_input(view, "#group-form", :group_image, [
        %{
          name: "to_cancel.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("to_cancel.jpg")

      # Should show uploaded
      assert render(view) =~ "Image uploaded"

      # Cancel the pending image
      view |> element("button[phx-click='cancel_pending_image']") |> render_click()

      # Should no longer show uploaded
      refute render(view) =~ "Image uploaded"
    end

    test "re-uploading replaces previous pending image", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      # First upload
      file_input(view, "#group-form", :group_image, [
        %{
          name: "first.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("first.jpg")

      # Capture the first image ID from the database
      first_images =
        GroupImage
        |> Ash.Query.filter(is_nil(group_id) and is_nil(deleted_at))
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(1)
        |> Ash.read!(authorize?: false)

      first_image = List.first(first_images)
      assert first_image != nil, "First image should have been created"

      # Second upload
      file_input(view, "#group-form", :group_image, [
        %{
          name: "second.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("second.jpg")

      # Check that the first image is now soft-deleted
      reloaded_first = Ash.get!(GroupImage, first_image.id, authorize?: false)

      assert reloaded_first.deleted_at != nil,
             "First image should be soft-deleted after re-upload"
    end

    test "form validation errors preserve pending image", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      # Upload a file first
      file_input(view, "#group-form", :group_image, [
        %{
          name: "preserved.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("preserved.jpg")

      # Should show uploaded
      assert render(view) =~ "Image uploaded"

      # Submit without required fields
      view
      |> form("#group-form", %{
        "form" => %{
          "name" => ""
        }
      })
      |> render_submit()

      # Should show error but preserve image
      html = render(view)
      assert html =~ "is required"
      assert html =~ "Image uploaded"
    end
  end

  describe "GroupLive.Edit - image upload" do
    setup do
      owner = generate(user(role: :user))

      group =
        generate(
          group(
            name: "Edit Test Group",
            slug: "edit-test-group",
            is_public: true,
            owner_id: owner.id,
            actor: owner
          )
        )

      %{owner: owner, group: group}
    end

    test "shows image upload area", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/edit")

      assert has_element?(view, "label", "Group Image")
      assert has_element?(view, "*", "Upload a banner image")
    end

    test "shows current image when group has one", %{conn: conn, owner: owner, group: group} do
      # Add an image to the group
      {:ok, _image} =
        Communities.create_group_image(
          %{
            filename: "existing.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/existing.jpg",
            thumbnail_path: "/uploads/group_images/#{group.id}/existing_thumb.jpg",
            group_id: group.id
          },
          actor: owner
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/edit")

      assert has_element?(view, "*", "Current image")
    end

    test "uploading new image shows pending preview", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/edit")

      # Upload a file
      file_input(view, "#edit-group-form", :group_image, [
        %{
          name: "new_banner.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("new_banner.jpg")

      html = render(view)
      assert html =~ "New image uploaded. Save to apply."
    end

    test "saving assigns pending image to group", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/edit")

      # Upload a file
      file_input(view, "#edit-group-form", :group_image, [
        %{
          name: "save_test.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("save_test.jpg")

      # Submit form
      view
      |> form("#edit-group-form", %{
        "form" => %{
          "name" => "Edit Test Group"
        }
      })
      |> render_submit()

      # Should redirect
      assert_redirected(view, "/groups/edit-test-group")

      # Verify group has image
      updated_group =
        Group
        |> Ash.get!(group.id, authorize?: false)
        |> Ash.load!(:current_image_url, authorize?: false)

      assert updated_group.current_image_url != nil
    end

    test "cancel pending image shows current image again", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      # Add an existing image
      {:ok, _image} =
        Communities.create_group_image(
          %{
            filename: "current.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/current.jpg",
            thumbnail_path: "/uploads/group_images/#{group.id}/current_thumb.jpg",
            group_id: group.id
          },
          actor: owner
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/edit")

      # Should show current image
      assert has_element?(view, "*", "Current image")

      # Upload new file
      file_input(view, "#edit-group-form", :group_image, [
        %{
          name: "replacement.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("replacement.jpg")

      # Should show pending preview
      assert render(view) =~ "New image uploaded"
      refute render(view) =~ "Current image"

      # Cancel pending
      view |> element("button[phx-click='cancel_pending_image']") |> render_click()

      # Should show current image again
      assert has_element?(view, "*", "Current image")
      refute render(view) =~ "New image uploaded"
    end

    test "non-owner cannot access edit page", %{conn: conn, group: group} do
      other_user = generate(user(role: :user))

      # Should redirect with an error
      {:error, {:redirect, %{to: to, flash: flash}}} =
        conn
        |> login(other_user)
        |> live(~p"/groups/#{group.slug}/edit")

      assert to == "/groups/edit-test-group"
      assert flash["error"] =~ "permission"
    end

    test "removing existing image works", %{conn: conn, owner: owner, group: group} do
      # Add an existing image
      {:ok, _image} =
        Communities.create_group_image(
          %{
            filename: "to_remove.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/to_remove.jpg",
            thumbnail_path: "/uploads/group_images/#{group.id}/to_remove_thumb.jpg",
            group_id: group.id
          },
          actor: owner
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/edit")

      # Should show current image with remove button
      assert has_element?(view, "*", "Current image")
      assert has_element?(view, "button[phx-click='remove_image']")

      # Remove the image
      view |> element("button[phx-click='remove_image']") |> render_click()

      # Verify image was removed
      updated_group =
        Group
        |> Ash.get!(group.id, authorize?: false)
        |> Ash.load!(:current_image_url, authorize?: false)

      assert updated_group.current_image_url == nil
    end
  end

  describe "Pending image cleanup" do
    setup do
      owner = generate(user(role: :user))
      %{owner: owner}
    end

    test "orphaned pending images have nil group_id", %{conn: conn, owner: owner} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/new")

      # Upload a file but don't submit
      file_input(view, "#group-form", :group_image, [
        %{
          name: "orphan.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("orphan.jpg")

      # Navigate away (implicit - just don't submit)
      # The pending image should exist with nil group_id

      pending_images =
        GroupImage
        |> Ash.Query.filter(is_nil(group_id) and is_nil(deleted_at))
        |> Ash.read!(authorize?: false)

      assert length(pending_images) >= 1
      assert Enum.all?(pending_images, fn img -> img.group_id == nil end)
    end
  end
end
