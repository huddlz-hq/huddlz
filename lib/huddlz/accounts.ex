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
    end
  end

  # Helper functions for role checking
  def admin?(nil), do: false
  def admin?(user) when is_struct(user), do: user.role == :admin

  def verified?(nil), do: false
  def verified?(user) when is_struct(user), do: user.role == :verified || user.role == :admin

  # Helper function to check if a user can perform an action
  def check_permission(action, user) do
    # For admin-specific actions, directly check user's role
    case action do
      :update_role -> admin?(user)
      :search_by_email -> admin?(user)
      _ -> Ash.can?({Huddlz.Accounts.User, action}, user, pre_flight?: false)
    end
  end
end
