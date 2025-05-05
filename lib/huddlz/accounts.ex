defmodule Huddlz.Accounts do
  use Ash.Domain,
    otp_app: :huddlz

  resources do
    resource Huddlz.Accounts.Token
    resource Huddlz.Accounts.User do
      define :get_by_email, args: [:email], action: :get_by_email
    end
  end
end
