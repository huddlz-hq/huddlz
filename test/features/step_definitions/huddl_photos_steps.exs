defmodule HuddlPhotosSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Huddlz.Generator
  @endpoint HuddlzWeb.Endpoint
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Huddlz.Test.Helpers.Authentication
  alias Huddlz.Communities
  alias Huddlz.Storage.HuddlPhotos

  step "a completed huddl with two shared photos", context do
    owner = generate(user(display_name: "Sam Rivera"))
    group = generate(group(owner_id: owner.id, actor: owner))
    huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

    photos =
      for name <- ["friends.jpg", "sunset.jpg"] do
        {:ok, metadata} =
          HuddlPhotos.store(
            "test/fixtures/test_image.jpg",
            name,
            "image/jpeg",
            huddl.id
          )

        Communities.create_huddl_photo!(
          Map.merge(metadata, %{filename: name, content_type: "image/jpeg", huddl_id: huddl.id}),
          actor: owner
        )
      end

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_photos/#{huddl.id}")
    end)

    Map.merge(context, %{
      owner: owner,
      huddl: huddl,
      photos: photos,
      gallery_path: "/groups/#{group.slug}/huddlz/#{huddl.id}"
    })
  end

  step "I open its gallery in two tabs and remove a photo in one", context do
    {:ok, first, _} = context.conn |> login(context.owner) |> live(context.gallery_path)
    {:ok, second, _} = context.conn |> login(context.owner) |> live(context.gallery_path)
    photo = hd(context.photos)
    first |> element("button[phx-value-url='#{photo.storage_path}']") |> render_click()
    second |> element("button[phx-value-id='#{photo.id}']") |> render_click()
    second |> element("#confirm-delete-photo") |> render_click()
    Map.merge(context, %{first_gallery: first, removed: photo})
  end

  step "the other gallery no longer offers the removed photo", context do
    refute has_element?(
             context.first_gallery,
             "button[phx-value-url='#{context.removed.storage_path}']"
           )

    refute has_element?(context.first_gallery, "#photo-lightbox")
    assert has_element?(context.first_gallery, ".photo-tile")
    context
  end

  step "one photo cannot currently be removed from storage", context do
    photo = hd(context.photos)
    path = Path.join("priv/static", photo.storage_path)
    File.rm!(path)
    File.mkdir_p!(path)
    Map.put(context, :blocked_photo, photo)
  end

  step "I try to remove that photo", context do
    {:ok, view, _} = context.conn |> login(context.owner) |> live(context.gallery_path)
    view |> element("button[phx-value-id='#{context.blocked_photo.id}']") |> render_click()
    view |> element("#confirm-delete-photo") |> render_click()
    Map.put(context, :gallery, view)
  end

  step "I see that deletion failed and can still view the gallery", context do
    assert has_element?(context.gallery, "#flash-error", "Failed to delete photo.")

    assert has_element?(
             context.gallery,
             "button[phx-value-url='#{context.blocked_photo.storage_path}']"
           )

    context
  end
end
