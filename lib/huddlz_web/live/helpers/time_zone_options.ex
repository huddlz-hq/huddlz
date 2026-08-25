defmodule HuddlzWeb.Live.Helpers.TimeZoneOptions do
  @moduledoc """
  IANA timezone `<.select>` options, shared by the group, huddl, and profile
  timezone pickers.

  `Tzdata.zone_list/0` returns ~600 entries; every form containing a picker
  would otherwise rebuild and re-sort the whole list on every render. The
  result is cached in `:persistent_term` on first use rather than at compile
  time, so a runtime tzdata release update is still picked up on the next boot.
  """

  @cache_key {__MODULE__, :options}

  @spec options() :: [{String.t(), String.t()}]
  def options do
    case :persistent_term.get(@cache_key, nil) do
      nil ->
        options = build_options()
        :persistent_term.put(@cache_key, options)
        options

      options ->
        options
    end
  end

  defp build_options do
    Tzdata.zone_list()
    |> Enum.sort()
    |> Enum.map(&{&1, &1})
  end
end
