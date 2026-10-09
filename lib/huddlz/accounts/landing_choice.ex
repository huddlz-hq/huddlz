defmodule Huddlz.Accounts.LandingChoice do
  @moduledoc """
  What a person said they came to huddlz for, asked once after signing in.

  `:unasked` means the question has not been answered yet, so it is still
  worth asking. `:my_huddlz` lands them on the agenda; `:find_a_huddl` lands
  them on Discover.
  """

  use Ash.Type.Enum, values: [:unasked, :my_huddlz, :find_a_huddl]
end
