defmodule HuddlzWeb.Components.Sparkline do
  @moduledoc """
  A small inline SVG line for a KPI tile. Server-rendered, no chart
  library: the app allows no vendor scripts, and a sparkline is a
  polyline.

  The points are also written to `data-points` so the figure can be read
  back in words, by tests and by anyone inspecting the markup. With no
  points at all the box draws a muted dashed baseline and carries
  `data-empty`, so a tile with nothing to chart keeps the shape of its
  neighbours instead of ending in a blank.
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :points, :list, required: true, doc: "numbers, oldest first"
  attr :class, :any, default: nil

  def sparkline(assigns) do
    assigns = assign(assigns, :path, path(assigns.points))

    ~H"""
    <svg
      id={@id}
      class={["spark", @class]}
      viewBox="0 0 100 28"
      preserveAspectRatio="none"
      aria-hidden="true"
      data-points={Enum.join(@points, ",")}
      data-count={length(@points)}
      data-empty={@points == [] || nil}
    >
      <line
        :if={@points == []}
        x1="0"
        y1="24"
        x2="100"
        y2="24"
        stroke="currentColor"
        stroke-width="2"
        stroke-dasharray="3 3"
        vector-effect="non-scaling-stroke"
      />
      <polyline
        :if={@points != []}
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linejoin="round"
        stroke-linecap="round"
        points={@path}
      />
    </svg>
    """
  end

  # Fit the points to the 100×28 box with a little headroom. A flat line
  # (every value equal, including all zeros) sits low rather than mid-box,
  # so an empty history reads as quiet rather than as a trend.
  defp path([]), do: ""
  defp path([_one] = points), do: path(points ++ points)

  defp path(points) do
    lo = Enum.min(points)
    hi = Enum.max(points)
    range = if hi == lo, do: 1, else: hi - lo
    step = 100 / (length(points) - 1)

    points
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {value, i} ->
      x = i * step
      y = if hi == lo, do: 24.0, else: 2 + 24 * (1 - (value - lo) / range)
      "#{Float.round(x * 1.0, 1)},#{Float.round(y * 1.0, 1)}"
    end)
  end
end
