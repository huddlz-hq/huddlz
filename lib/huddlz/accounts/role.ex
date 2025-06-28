defmodule Huddlz.Accounts.Role do
  @moduledoc """
  Enum type for user roles: admin and user.
  """

  use Ash.Type.Enum, values: [:admin, :user]
end
