defmodule Huddlz.Accounts do
  @moduledoc """
  The Accounts domain handles user authentication and authorization.
  """

  use Ash.Domain,
    otp_app: :huddlz

  resources do
    resource Huddlz.Accounts.Token

    resource Huddlz.Accounts.User do
      # Define proper code interfaces for actions
      define :search_by_email, action: :search_by_email, args: [:email]
      define :update_role, action: :update_role, args: [:role]
      define :get_by_email, action: :get_by_email, args: [:email]
      define :update_display_name, action: :update_display_name, args: [:display_name]

      define :update_home_location,
        action: :update_home_location,
        args: [:home_location, :home_latitude, :home_longitude]
    end

    resource Huddlz.Accounts.ProfilePicture do
      define :create_profile_picture, action: :create
      define :get_current_profile_picture, action: :get_current_for_user, args: [:user_id]
      define :list_profile_pictures, action: :list_for_user, args: [:user_id]
      define :delete_profile_picture, action: :destroy
      define :soft_delete_profile_picture, action: :soft_delete
    end
  end
end
