defmodule Huddlz.Communities.HuddlPhotoTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlAttendee

  describe "create action (upload)" do
    test "the huddl creator can upload a photo after the huddl ends" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      attrs = %{
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_photos/#{huddl.id}/photo.jpg",
        thumbnail_path: "/uploads/huddl_photos/#{huddl.id}/photo_thumb.jpg",
        huddl_id: huddl.id
      }

      assert {:ok, photo} = Communities.create_huddl_photo(attrs, actor: owner)
      assert photo.uploader_id == owner.id
      assert photo.huddl_id == huddl.id
    end

    test "a confirmed attendee can upload a photo after the huddl ends" do
      owner = generate(user(role: :user))
      attendee = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      Communities.rsvp_huddl!(huddl, actor: attendee)

      attrs = %{
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_photos/#{huddl.id}/attendee.jpg",
        huddl_id: huddl.id
      }

      assert {:ok, photo} = Communities.create_huddl_photo(attrs, actor: attendee)
      assert photo.uploader_id == attendee.id
    end

    test "a waitlisted-only user cannot upload a photo" do
      owner = generate(user(role: :user))
      waitlisted = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      HuddlAttendee
      |> Ash.Changeset.for_create(
        :join_waitlist,
        %{huddl_id: huddl.id, user_id: waitlisted.id},
        actor: waitlisted
      )
      |> Ash.create!()

      attrs = %{
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_photos/#{huddl.id}/waitlisted.jpg",
        huddl_id: huddl.id
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.create_huddl_photo!(attrs, actor: waitlisted)
      end
    end

    test "a non-attendee group member cannot upload a photo" do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      generate(group_member(group_id: group.id, user_id: member.id, role: "member", actor: owner))

      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      attrs = %{
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_photos/#{huddl.id}/blocked.jpg",
        huddl_id: huddl.id
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.create_huddl_photo!(attrs, actor: member)
      end
    end

    test "the creator cannot upload a photo before the huddl ends" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      attrs = %{
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_photos/#{huddl.id}/early.jpg",
        huddl_id: huddl.id
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.create_huddl_photo!(attrs, actor: owner)
      end
    end

    test "the creator cannot upload a photo to a cancelled huddl" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      # Use a not-yet-ended huddl: TransitionLifecycle refuses to cancel a
      # huddl whose ends_at has already passed ("A completed huddl cannot be
      # cancelled."), so past_huddl can't be cancelled here.
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
      cancelled_huddl = Communities.cancel_huddl!(huddl, nil, actor: owner)

      attrs = %{
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size_bytes: 50_000,
        storage_path: "/uploads/huddl_photos/#{cancelled_huddl.id}/cancelled.jpg",
        huddl_id: cancelled_huddl.id
      }

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.create_huddl_photo!(attrs, actor: owner)
      end
    end
  end

  describe "list_for_huddl action (read)" do
    test "an ineligible user gets no photos back" do
      owner = generate(user(role: :user))
      outsider = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, _photo} =
        Communities.create_huddl_photo(
          %{
            filename: "photo.jpg",
            content_type: "image/jpeg",
            size_bytes: 50_000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/photo.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      assert {:ok, []} = Communities.list_huddl_photos(huddl.id, actor: outsider)
    end

    test "returns photos newest first" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, first} =
        Communities.create_huddl_photo(
          %{
            filename: "first.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/first.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      {:ok, second} =
        Communities.create_huddl_photo(
          %{
            filename: "second.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/second.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      # Compare by id rather than pinning the full structs: relate_actor's
      # belongs_to path attaches the loaded actor to `uploader` on the
      # just-created record (see Ash.Resource.Change.RelateActor), while a
      # plain read leaves `uploader`/`huddl` as NotLoaded — so the created and
      # re-fetched structs are never `==`-equal even when order is correct.
      assert {:ok, [result_second, result_first]} =
               Communities.list_huddl_photos(huddl.id, actor: owner)

      assert result_second.id == second.id
      assert result_first.id == first.id
    end
  end

  describe "destroy action" do
    test "the uploader can delete their own photo" do
      owner = generate(user(role: :user))
      attendee = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      Communities.rsvp_huddl!(huddl, actor: attendee)

      {:ok, photo} =
        Communities.create_huddl_photo(
          %{
            filename: "photo.jpg",
            content_type: "image/jpeg",
            size_bytes: 50_000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/mine.jpg",
            huddl_id: huddl.id
          },
          actor: attendee
        )

      assert :ok = Communities.destroy_huddl_photo(photo, actor: attendee)
    end

    test "the huddl creator can delete any photo" do
      owner = generate(user(role: :user))
      attendee = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      Communities.rsvp_huddl!(huddl, actor: attendee)

      {:ok, photo} =
        Communities.create_huddl_photo(
          %{
            filename: "photo.jpg",
            content_type: "image/jpeg",
            size_bytes: 50_000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/theirs.jpg",
            huddl_id: huddl.id
          },
          actor: attendee
        )

      assert :ok = Communities.destroy_huddl_photo(photo, actor: owner)
    end

    test "another attendee cannot delete someone else's photo" do
      owner = generate(user(role: :user))
      uploader = generate(user(role: :user))
      other_attendee = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      Communities.rsvp_huddl!(huddl, actor: uploader)
      Communities.rsvp_huddl!(huddl, actor: other_attendee)

      {:ok, photo} =
        Communities.create_huddl_photo(
          %{
            filename: "photo.jpg",
            content_type: "image/jpeg",
            size_bytes: 50_000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/not_yours.jpg",
            huddl_id: huddl.id
          },
          actor: uploader
        )

      assert_raise Ash.Error.Forbidden, fn ->
        Communities.destroy_huddl_photo!(photo, actor: other_attendee)
      end
    end
  end
end
