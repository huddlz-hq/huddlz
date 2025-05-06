defmodule Huddlz.Accounts do
  use Ash.Domain,
    otp_app: :huddlz

  resources do
    resource Huddlz.Accounts.Token
    resource Huddlz.Accounts.User
  end
end
