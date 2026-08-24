defmodule HuddlzWeb.Live.Helpers.TimeZoneOptions do
  @moduledoc """
  IANA timezone `<.select>` options, shared by the group, huddl, and profile
  timezone pickers.
  """

  @spec options() :: [{String.t(), String.t()}]
  def options do
    Tzdata.zone_list()
    |> Enum.sort()
    |> Enum.map(&{&1, &1})
  end
end
