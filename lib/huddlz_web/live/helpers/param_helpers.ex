defmodule HuddlzWeb.Live.Helpers.ParamHelpers do
  @moduledoc """
  Shared URL-param parsing for LiveViews.
  """

  @doc """
  Parses a `?page=` param, falling back to 1 for anything that isn't a
  positive integer.
  """
  def parse_page(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n >= 1 -> n
      _ -> 1
    end
  end

  def parse_page(val) when is_integer(val) and val >= 1, do: val
  def parse_page(_), do: 1
end
