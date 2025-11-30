defmodule GroupImageSteps do
  @moduledoc """
  Cucumber step definitions for group image management features.
  """
  use Cucumber.StepDefinition
  import PhoenixTest
  import Ash.Expr
  import ExUnit.Assertions

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupImage

  require Ash.Query

  # Note: The following steps are defined in SharedUISteps and should NOT be duplicated here:
  # - "I click {string}"
  # - "I should see {string}"
  # - "I should not see {string}"
  # - "I visit {string}"
  # - "I fill in {string} with {string}"

  # Note: "{string} is a member of {string}" step is defined in RsvpCancellationSteps

  # ===== Given Steps =====

  step "the group {string} has an image", %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> to_string(g.name) == group_name end)

    owner =
      Enum.find(context.users, fn u ->
        u.id == group.owner_id
      end)

    # Create a group image record (simulating an uploaded image)
    {:ok, _image} =
      Communities.create_group_image(
        %{
          filename: "test_banner.jpg",
          content_type: "image/jpeg",
          size_bytes: 10_000,
          storage_path: "/uploads/group_images/#{group.id}/test_banner.jpg",
          thumbnail_path: "/uploads/group_images/#{group.id}/test_banner_thumb.jpg",
          group_id: group.id
        },
        actor: owner
      )

    context
  end

  # ===== When Steps =====

  step "I visit the edit page for group {string}", %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> to_string(g.name) == group_name end)

    session = context[:session] || context[:conn]
    session = visit(session, "/groups/#{group.slug}/edit")

    context
    |> Map.merge(%{session: session, conn: session})
    |> Map.put(:current_group, group)
  end

  step "I upload {string} to {string}", %{args: [file_path, label]} = context do
    session = context[:session] || context[:conn]
    session = upload(session, label, file_path, exact: false)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I cancel the pending image", context do
    session = context[:session] || context[:conn]
    # Click the X button on the pending image preview
    session = click_button(session, "cancel_pending_image")
    Map.merge(context, %{session: session, conn: session})
  end

  # ===== Then Steps =====

  step "the group {string} should have an image", %{args: [group_name]} = context do
    group =
      Group
      |> Ash.Query.filter(expr(name == ^group_name))
      |> Ash.read_one!(authorize?: false)
      |> Ash.load!(:current_image_url, authorize?: false)

    assert group.current_image_url != nil,
           "Expected group '#{group_name}' to have an image, but current_image_url is nil"

    context
  end

  step "the group {string} should not have an image", %{args: [group_name]} = context do
    group =
      Group
      |> Ash.Query.filter(expr(name == ^group_name))
      |> Ash.read_one!(authorize?: false)
      |> Ash.load!(:current_image_url, authorize?: false)

    assert group.current_image_url == nil,
           "Expected group '#{group_name}' to have no image, but got: #{inspect(group.current_image_url)}"

    context
  end

  step "there should be only one pending image for the current user", context do
    # Count pending images (group_id is nil)
    pending_count =
      GroupImage
      |> Ash.Query.filter(is_nil(group_id))
      |> Ash.count!(authorize?: false)

    # There should be at most 1 pending image (the second upload should have soft-deleted the first)
    assert pending_count <= 1,
           "Expected at most 1 pending image, but found #{pending_count}"

    context
  end

  step "there should be an orphaned pending image", context do
    # Check that at least one pending image exists
    pending_count =
      GroupImage
      |> Ash.Query.filter(is_nil(group_id) and is_nil(deleted_at))
      |> Ash.count!(authorize?: false)

    assert pending_count >= 1,
           "Expected at least 1 orphaned pending image, but found #{pending_count}"

    context
  end

  step "I should see the group image", context do
    session = context[:session] || context[:conn]
    # Look for an image tag with src containing group_images path
    assert_has(session, "img[src*='group_images']")
    context
  end

  step "I should not see the group image", context do
    session = context[:session] || context[:conn]
    refute_has(session, "img[src*='group_images']")
    context
  end

  step "I should see the group name {string} in the placeholder",
       %{args: [group_name]} = context do
    session = context[:session] || context[:conn]

    # The placeholder div should contain the group name
    assert_has(session, "div.aspect-video span", text: group_name)
    context
  end

  step "I should be redirected to the group page", context do
    session = context[:session] || context[:conn]
    group = context[:current_group]

    if group do
      # Should be on the group show page, not edit
      assert_path(session, "/groups/#{group.slug}")
    else
      # Should be on groups index
      assert_has(session, "h1", text: "Groups")
    end

    context
  end
end
