defmodule HuddlzWeb.HuddlLive.ShowPhotosTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Phoenix.LiveViewTest

  alias Huddlz.Communities

  setup do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    %{owner: owner, group: group}
  end

  describe "photos section visibility" do
    test "creator sees the photos section on a completed huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      assert has_element?(view, ".huddl-photos h2", "Photos")
      assert has_element?(view, ".huddl-photos-empty")
    end

    test "confirmed attendee sees the photos section on a completed huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      attendee = generate(user(role: :user))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      Communities.rsvp_huddl!(huddl, actor: attendee)

      {:ok, view, _html} =
        conn
        |> login(attendee)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      assert has_element?(view, ".huddl-photos h2", "Photos")
    end

    test "a group member who never RSVPed does not see the photos section", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      outsider = generate(user(role: :user))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} =
        conn
        |> login(outsider)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos")
    end

    test "the creator does not see the photos section before the huddl ends", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos")
    end

    test "an anonymous visitor does not see the photos section", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos")
    end
  end

  describe "photos grid" do
    test "shows uploaded photos in the grid", %{conn: conn, owner: owner, group: group} do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, _photo} =
        Communities.create_huddl_photo(
          %{
            filename: "photo.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/photo.jpg",
            thumbnail_path: "/uploads/huddl_photos/#{huddl.id}/photo_thumb.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos-empty")
      assert has_element?(view, ".photo-tile img")
    end
  end

  describe "uploading photos" do
    @test_image_path "test/fixtures/test_image.jpg"

    test "creator can upload a single photo", %{conn: conn, owner: owner, group: group} do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      file_input(view, "#huddl-photo-upload-form", :huddl_photos, [
        %{
          name: "photo.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("photo.jpg")

      view
      |> element("#huddl-photo-upload-form")
      |> render_submit()

      assert render(view) =~ "Photos uploaded."

      assert {:ok, [_photo]} = Communities.list_huddl_photos(huddl.id, actor: owner)
    end

    test "confirmed attendee can upload multiple photos in one batch", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      attendee = generate(user(role: :user))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      Communities.rsvp_huddl!(huddl, actor: attendee)

      {:ok, view, _html} =
        conn
        |> login(attendee)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      image = File.read!(@test_image_path)

      file_input(view, "#huddl-photo-upload-form", :huddl_photos, [
        %{name: "one.jpg", content: image, type: "image/jpeg"}
      ])
      |> render_upload("one.jpg")

      file_input(view, "#huddl-photo-upload-form", :huddl_photos, [
        %{name: "two.jpg", content: image, type: "image/jpeg"}
      ])
      |> render_upload("two.jpg")

      view
      |> element("#huddl-photo-upload-form")
      |> render_submit()

      assert {:ok, photos} = Communities.list_huddl_photos(huddl.id, actor: attendee)
      assert length(photos) == 2
    end

    test "rejects a file that is too large", %{conn: conn, owner: owner, group: group} do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      too_big = String.duplicate("a", 5_000_001)

      upload =
        file_input(view, "#huddl-photo-upload-form", :huddl_photos, [
          %{name: "big.jpg", content: too_big, type: "image/jpeg"}
        ])

      assert {:error, [[_ref, :too_large]]} = render_upload(upload, "big.jpg")
      assert render(view) =~ "5 MB or smaller"
    end

    test "outsider cannot see or submit the upload form", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      outsider = generate(user(role: :user))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} =
        conn
        |> login(outsider)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, "#huddl-photo-upload-form")
    end

    test "cleans up the already-stored files when create_huddl_photo fails after a successful store",
         %{conn: conn, owner: owner, group: group} do
      attendee = generate(user(role: :user))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      Communities.rsvp_huddl!(huddl, actor: attendee)

      {:ok, view, _html} =
        conn
        |> login(attendee)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      # Revoke the attendee's confirmed-attendee status behind the LiveView's
      # back (bypassing the "cancel_rsvp" action, since it isn't guaranteed to
      # be callable on a completed huddl) so that, by the time the
      # "upload_photos" handle_event runs Communities.create_huddl_photo/2,
      # the actor is no longer authorized to create a photo record for this
      # huddl -- while HuddlPhotos.store/4 has already run and written the
      # original + thumbnail to storage.
      {:ok, [attendance]} = Communities.check_user_rsvp(huddl.id, actor: attendee)
      Ash.destroy!(attendance, authorize?: false)

      file_input(view, "#huddl-photo-upload-form", :huddl_photos, [
        %{
          name: "photo.jpg",
          content: File.read!(@test_image_path),
          type: "image/jpeg"
        }
      ])
      |> render_upload("photo.jpg")

      view
      |> element("#huddl-photo-upload-form")
      |> render_submit()

      assert render(view) =~ "Failed to upload photos. Please try again."
      assert {:ok, []} = Communities.list_huddl_photos(huddl.id, actor: owner)

      upload_dir = Path.join(["priv/static/uploads/huddl_photos", huddl.id])
      assert File.ls(upload_dir) in [{:ok, []}, {:error, :enoent}]
    end
  end

  describe "deleting photos" do
    setup %{owner: owner, group: group} do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, photo} =
        Communities.create_huddl_photo(
          %{
            filename: "photo.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/photo.jpg",
            thumbnail_path: "/uploads/huddl_photos/#{huddl.id}/photo_thumb.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      %{huddl: huddl, photo: photo}
    end

    test "uploader sees a delete button and a confirmation before deleting", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl,
      photo: photo
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      view
      |> element("button[phx-click='confirm_delete_photo'][phx-value-id='#{photo.id}']")
      |> render_click()

      assert has_element?(view, "#delete-photo-modal")

      view |> element("#cancel-delete-photo") |> render_click()
      refute has_element?(view, "#delete-photo-modal[style*='display: block']")

      assert {:ok, [_photo]} = Communities.list_huddl_photos(huddl.id, actor: owner)

      view
      |> element("button[phx-click='confirm_delete_photo'][phx-value-id='#{photo.id}']")
      |> render_click()

      view |> element("#confirm-delete-photo") |> render_click()

      assert {:ok, []} = Communities.list_huddl_photos(huddl.id, actor: owner)
    end

    test "another attendee cannot delete someone else's photo", %{
      conn: conn,
      owner: _owner,
      group: group,
      huddl: huddl,
      photo: photo
    } do
      other_attendee = generate(user(role: :user))
      Communities.rsvp_huddl!(huddl, actor: other_attendee)

      {:ok, view, _html} =
        conn
        |> login(other_attendee)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(
               view,
               "button[phx-click='confirm_delete_photo'][phx-value-id='#{photo.id}']"
             )
    end
  end
end
