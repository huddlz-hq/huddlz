defmodule Huddlz.Accounts.ThemePreference do
  @moduledoc """
  How the app should look for a user: follow the device (`:system`), or
  always `:light` / `:dark`.
  """

  use Ash.Type.Enum, values: [:system, :light, :dark]
end
