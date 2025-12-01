defmodule HuddlzWeb.HuddlLive.NewImageUploadTest do
  @moduledoc """
  Tests for huddl image upload functionality in HuddlLive.New.
  """
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Phoenix.LiveViewTest

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlImage

  require Ash.Query

  @test_image_path "test/fixtures/test_image.jpg"

  describe "HuddlLive.New - image upload" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "shows image upload area", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new")

      assert has_element?(view, "label", "Huddl Image")
      assert has_element?(view, "*", "Upload a banner image")
      assert has_element?(view, "*", "Click to upload or drag and drop")
      assert has_element?(view, "*", "JPG, PNG, or WebP (max 5MB)")
    end

    test "creates huddl without image", %{conn: conn, owner: owner, group: group} do
      tomorrow = Date.utc_today() |> Date.add(1)

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new")

      view
      |> form("#huddl-form", %{
        "form" => %{
          "title" => "No Image Huddl",
          "description" => "A huddl without an image",
          "date" => Date.to_iso8601(tomorrow),
          "start_time" => "14:00",
          "duration_minutes" => "60",
          "event_type" => "in_person",
          "physical_location" => "Test Location"
        }
      })
      |> render_submit()

      # Should redirect to group page
      assert_redirected(view, "/groups/#{group.slug}")

      # Verify huddl was created without image
      huddl =
        Huddl
        |> Ash.Query.filter(title: "No Image Huddl")
        |> Ash.read_one!(authorize?: false)
        |> Ash.load!(:current_image_url, authorize?: false)

      assert huddl.current_image_url == nil
    end

    test "eager upload creates pending image immediately", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new")

      # Upload a file - this is the critical test that should fail with the bug
      file_input(view, "#huddl-form", :huddl_image, [
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
        HuddlImage
        |> Ash.Query.filter(is_nil(huddl_id) and is_nil(deleted_at))
        |> Ash.count!(authorize?: false)

      assert pending_count >= 1
    end

    test "form submit assigns pending image to new huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      tomorrow = Date.utc_today() |> Date.add(1)

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new")

      # Upload a file first
      file_input(view, "#huddl-form", :huddl_image, [
        %{
          name: "banner.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("banner.jpg")

      # Should show uploaded confirmation
      assert render(view) =~ "Image uploaded"

      # Submit form with required fields
      view
      |> form("#huddl-form", %{
        "form" => %{
          "title" => "Image Upload Huddl",
          "description" => "A huddl with an image",
          "date" => Date.to_iso8601(tomorrow),
          "start_time" => "14:00",
          "duration_minutes" => "60",
          "event_type" => "in_person",
          "physical_location" => "Test Location"
        }
      })
      |> render_submit()

      # Should redirect to group page
      assert_redirected(view, "/groups/#{group.slug}")

      # Verify huddl has image
      huddl =
        Huddl
        |> Ash.Query.filter(title: "Image Upload Huddl")
        |> Ash.read_one!(authorize?: false)
        |> Ash.load!(:current_image_url, authorize?: false)

      assert huddl.current_image_url != nil
    end

    test "cancel pending image removes preview", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new")

      # Upload a file
      file_input(view, "#huddl-form", :huddl_image, [
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
  end
end
