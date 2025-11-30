defmodule HuddlImageSteps do
  @moduledoc """
  Cucumber step definitions for huddl image management features.
  """
  use Cucumber.StepDefinition
  import PhoenixTest
  import Ash.Expr
  import ExUnit.Assertions

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl

  require Ash.Query

  # ===== Given Steps =====

  step "the huddl {string} has an image", %{args: [huddl_title]} = context do
    huddl =
      Huddl
      |> Ash.Query.filter(expr(title == ^huddl_title))
      |> Ash.Query.load(:group)
      |> Ash.read_one!(authorize?: false)

    group = huddl.group

    owner =
      Enum.find(context.users, fn u ->
        u.id == group.owner_id
      end)

    {:ok, _image} =
      Communities.create_huddl_image(
        %{
          filename: "huddl_banner.jpg",
          content_type: "image/jpeg",
          size_bytes: 10_000,
          storage_path: "/uploads/huddl_images/#{huddl.id}/huddl_banner.jpg",
          thumbnail_path: "/uploads/huddl_images/#{huddl.id}/huddl_banner_thumb.jpg",
          huddl_id: huddl.id
        },
        actor: owner
      )

    context
  end

  step "{string} is an organizer of {string}", %{args: [email, group_name]} = context do
    user = Enum.find(context.users, fn u -> to_string(u.email) == email end)
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> to_string(g.name) == group_name end)

    Ash.Seed.seed!(GroupMember, %{
      group_id: group.id,
      user_id: user.id,
      role: :organizer
    })

    context
  end

  # ===== When Steps =====

  step "I visit the new huddl page for group {string}", %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> to_string(g.name) == group_name end)

    session = context[:session] || context[:conn]
    session = visit(session, "/groups/#{group.slug}/huddlz/new")

    context
    |> Map.merge(%{session: session, conn: session})
    |> Map.put(:current_group, group)
  end

  step "I visit the edit page for huddl {string}", %{args: [huddl_title]} = context do
    huddl =
      Huddl
      |> Ash.Query.filter(expr(title == ^huddl_title))
      |> Ash.Query.load(:group)
      |> Ash.read_one!(authorize?: false)

    session = context[:session] || context[:conn]
    session = visit(session, "/groups/#{huddl.group.slug}/huddlz/#{huddl.id}/edit")

    context
    |> Map.merge(%{session: session, conn: session})
    |> Map.put(:current_huddl, huddl)
  end

  step "I visit the huddl page for {string}", %{args: [huddl_title]} = context do
    huddl =
      Huddl
      |> Ash.Query.filter(expr(title == ^huddl_title))
      |> Ash.Query.load(:group)
      |> Ash.read_one!(authorize?: false)

    session = context[:session] || context[:conn]
    session = visit(session, "/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")

    context
    |> Map.merge(%{session: session, conn: session})
    |> Map.put(:current_huddl, huddl)
  end

  # ===== Then Steps =====

  step "the huddl {string} should have its own image", %{args: [huddl_title]} = context do
    huddl =
      Huddl
      |> Ash.Query.filter(expr(title == ^huddl_title))
      |> Ash.read_one!(authorize?: false)
      |> Ash.load!([:current_image_url, :display_image_url], authorize?: false)

    assert huddl.current_image_url != nil,
           "Expected huddl '#{huddl_title}' to have its own image, but current_image_url is nil"

    assert huddl.display_image_url == huddl.current_image_url,
           "Expected display_image_url to match current_image_url"

    context
  end

  step "the huddl {string} should use the group image", %{args: [huddl_title]} = context do
    huddl =
      Huddl
      |> Ash.Query.filter(expr(title == ^huddl_title))
      |> Ash.Query.load(group: [:current_image_url])
      |> Ash.read_one!(authorize?: false)
      |> Ash.load!([:current_image_url, :display_image_url], authorize?: false)

    assert huddl.current_image_url == nil,
           "Expected huddl to not have its own image"

    assert huddl.display_image_url == huddl.group.current_image_url,
           "Expected huddl to use group image, got display_image_url: #{inspect(huddl.display_image_url)}"

    context
  end

  step "I should see the group fallback image", context do
    session = context[:session] || context[:conn]
    # Look for an image tag with src containing group_images path (fallback)
    assert_has(session, "img[src*='group_images']")
    context
  end

  step "I should see the huddl image", context do
    session = context[:session] || context[:conn]
    # Look for an image tag with src containing huddl_images path
    assert_has(session, "img[src*='huddl_images']")
    context
  end

  step "I should not see an image on the huddl page", context do
    session = context[:session] || context[:conn]
    # Should not see any storage image paths
    refute_has(session, "img[src*='group_images']")
    refute_has(session, "img[src*='huddl_images']")
    context
  end

  step "I should be redirected away from the edit page", context do
    session = context[:session] || context[:conn]
    huddl = context[:current_huddl]

    if huddl do
      # Should not be on the edit page
      refute_has(session, "h1", text: "Edit Huddl")
    end

    context
  end
end
