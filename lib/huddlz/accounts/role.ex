defmodule Huddlz.Accounts.Role do
  use Ash.Type.Enum, values: [:admin, :verified, :regular]
end
