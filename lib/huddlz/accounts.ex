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
    end
  end
end
