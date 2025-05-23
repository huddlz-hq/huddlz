defmodule Huddlz.Accounts.Role do
  @moduledoc """
  Enum type for user roles: admin, verified, and regular.
  """

  use Ash.Type.Enum, values: [:admin, :verified, :regular]
end
