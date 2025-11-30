defmodule Huddlz.Communities.Huddl.Calculations.DisplayImageUrl do
  @moduledoc """
  Calculation to return the huddl's display image URL.
  Falls back to the group's image if the huddl has no image.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    # Load both the huddl's image and the group's image for fallback
    [:current_image_url, group: [:current_image_url]]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      cond do
        is_binary(record.current_image_url) ->
          record.current_image_url

        is_struct(record.group) and is_binary(record.group.current_image_url) ->
          record.group.current_image_url

        true ->
          nil
      end
    end)
  end
end
