defmodule ProfilePictureSteps do
  @moduledoc """
  Cucumber step definitions for profile picture management features.
  """
  use Cucumber.StepDefinition
  import PhoenixTest
  import Huddlz.Generator

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User

  # Given steps
  step "the following profile pictures exist:", context do
    for row <- context.datatable.maps do
      user = Huddlz.Repo.get_by!(User, email: row["user_email"])

      storage_path = row["storage_path"]
      # Generate thumbnail path from storage path (same pattern as real uploads)
      thumbnail_path = String.replace(storage_path, ~r/\.\w+$/, "_thumb.jpg")

      Accounts.create_profile_picture!(
        %{
          filename: "avatar.jpg",
          content_type: "image/jpeg",
          size_bytes: 1000,
          storage_path: storage_path,
          thumbnail_path: thumbnail_path,
          user_id: user.id
        },
        actor: user
      )
    end

    context
  end

  # Then steps
  step "I should see the avatar fallback showing initials", context do
    # The avatar component shows initials when no profile picture is set
    # Verify no thumbnail image is shown in the main content area
    session = context[:session] || context[:conn]
    refute_has(session, "main img[src*='_thumb.jpg']")
    # Verify we see the initials "AU" (Alice User) in the avatar
    assert_has(session, "[class*='rounded-full']", text: "AU")
    context
  end

  step "I should see the navbar avatar with image", context do
    # The navbar avatar should contain an img tag when user has profile picture
    # Now looking for thumbnail paths which end with _thumb.jpg
    assert_has(context.session, "header img[src*='_thumb.jpg']")
    context
  end

  step "I should see the navbar avatar with initials {string}", %{args: [initials]} = context do
    # The navbar avatar should show initials when no profile picture
    session = context[:session] || context[:conn]
    assert_has(session, "header", text: initials)
    context
  end

  step "I should see the member avatar with image", context do
    # The member section should contain an img tag when user has profile picture
    # Now looking for thumbnail paths which end with _thumb.jpg
    session = context[:session] || context[:conn]
    assert_has(session, "main img[src*='_thumb.jpg']")
    context
  end

  step "I should see the owner avatar with image", context do
    # The owner in Group Details section should show profile picture image
    # The owner section is in a definition list (dl) with "Owner" label
    # Now looking for thumbnail paths which end with _thumb.jpg
    session = context[:session] || context[:conn]
    assert_has(session, "dd img[src*='_thumb.jpg']")
    context
  end

  step "a huddl {string} exists in {string} created by {string}",
       %{args: [title, group_name, creator_email]} = context do
    creator = Enum.find(context.users, &(to_string(&1.email) == creator_email))
    group = Enum.find(context.groups, &(to_string(&1.name) == group_name))

    huddl =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: creator.id,
          is_private: false,
          actor: creator
        )
      )

    huddlz = Map.get(context, :huddlz, [])
    Map.put(context, :huddlz, [huddl | huddlz])
  end

  step "I visit the huddl {string} page", %{args: [title]} = context do
    huddl = Enum.find(context.huddlz, &(to_string(&1.title) == title))
    group = Enum.find(context.groups, &(&1.id == huddl.group_id))

    session = context[:session] || context[:conn]
    session = visit(session, "/groups/#{group.slug}/huddlz/#{huddl.id}")

    context
    |> Map.merge(%{session: session, conn: session})
    |> Map.put(:current_huddl, huddl)
  end

  step "I should see the creator avatar with image", context do
    # The creator/organizer section should show profile picture image
    # Now looking for thumbnail paths which end with _thumb.jpg
    session = context[:session] || context[:conn]
    # Look for the "Organized by" section which contains the creator avatar
    assert_has(session, "main img[src*='_thumb.jpg']")
    context
  end
end
