defmodule Huddlz.Accounts.DisplayTimeZoneMode do
  @moduledoc """
  Whether schedule presentation follows the current browser or a saved zone.
  """

  use Ash.Type.Enum, values: [:automatic, :fixed]
end
