defmodule Huddlz.Communities.Huddl.Calculations.ImageUrl do
  @moduledoc """
  Resolves the shared display artwork path to a URL API clients can fetch.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:display_image_url]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &image_url(&1.display_image_url))
  end

  defp image_url(nil), do: nil

  defp image_url(path) do
    HuddlzWeb.Endpoint.url()
    |> URI.merge(Huddlz.Storage.url(path))
    |> URI.to_string()
  end
end
