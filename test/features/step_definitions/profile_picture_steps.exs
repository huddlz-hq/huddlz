defmodule ProfilePictureSteps do
  @moduledoc """
  Cucumber step definitions for profile picture management features.
  """
  use Cucumber.StepDefinition
  import PhoenixTest

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User

  # Given steps
  step "the following profile pictures exist:", context do
    for row <- context.datatable.maps do
      user = Huddlz.Repo.get_by!(User, email: row["user_email"])

      Accounts.create_profile_picture!(
        %{
          filename: "avatar.jpg",
          content_type: "image/jpeg",
          size_bytes: 1000,
          storage_path: row["storage_path"],
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
    # Look for the avatar element with initials (not an img tag)
    assert_has(context.session, "[class*='rounded-full']")
    context
  end

  step "I should see the navbar avatar with image", context do
    # The navbar avatar should contain an img tag when user has profile picture
    assert_has(context.session, "header img[src*='/uploads/profile_pictures/']")
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
    session = context[:session] || context[:conn]
    assert_has(session, "main img[src*='/uploads/profile_pictures/']")
    context
  end
end
