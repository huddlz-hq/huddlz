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

  A `nil` point is a bucket with nothing measured, as distinct from a
  measured zero: the line breaks there, and a measured point with no
  neighbour is drawn as a dot.
  """
  use Phoenix.Component

  attr :id, :string, required: true

  attr :points, :list,
    required: true,
    doc: "numbers, oldest first; nil where nothing was measured"

  attr :class, :any, default: nil

  def sparkline(assigns) do
    assigns = assign(assigns, :runs, runs(assigns.points))

    ~H"""
    <svg
      id={@id}
      class={["spark", @class]}
      viewBox="0 0 100 28"
      preserveAspectRatio="none"
      aria-hidden="true"
      data-points={Enum.map_join(@points, ",", &(&1 || ""))}
      data-count={length(@points)}
      data-empty={@runs == [] || nil}
    >
      <line
        :if={@runs == []}
        x1="0"
        y1="24"
        x2="100"
        y2="24"
        stroke="currentColor"
        stroke-width="2"
        stroke-dasharray="3 3"
        vector-effect="non-scaling-stroke"
      />
      <%= for run <- @runs do %>
        <polyline
          :if={length(run) > 1}
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
          points={Enum.map_join(run, " ", fn {x, y} -> "#{x},#{y}" end)}
        />
        <circle
          :if={length(run) == 1}
          cx={elem(hd(run), 0)}
          cy={elem(hd(run), 1)}
          r="2"
          fill="currentColor"
        />
      <% end %>
    </svg>
    """
  end

  # Consecutive measured points become one run of `{x, y}` pairs; a nil
  # ends a run. Every run shares one scale so the line reads across gaps.
  defp runs(points) do
    case Enum.reject(points, &is_nil/1) do
      [] ->
        []

      measured ->
        scale = scale(measured, length(points))

        points
        |> Enum.with_index()
        |> Enum.chunk_by(fn {value, _i} -> is_nil(value) end)
        |> Enum.reject(fn [{value, _i} | _] -> is_nil(value) end)
        |> Enum.map(fn run -> Enum.map(run, &plot(&1, scale)) end)
    end
  end

  # Fit the points to the 100×28 box with a little headroom. A flat line
  # (every value equal, including all zeros) sits low rather than mid-box,
  # so an empty history reads as quiet rather than as a trend.
  defp scale(measured, count) do
    lo = Enum.min(measured)
    hi = Enum.max(measured)

    %{
      lo: lo,
      flat?: hi == lo,
      range: if(hi == lo, do: 1, else: hi - lo),
      step: if(count > 1, do: 100 / (count - 1), else: 0),
      single?: count == 1
    }
  end

  defp plot({value, i}, scale) do
    x = if scale.single?, do: 50, else: i * scale.step
    y = if scale.flat?, do: 24.0, else: 2 + 24 * (1 - (value - scale.lo) / scale.range)
    {Float.round(x * 1.0, 1), Float.round(y * 1.0, 1)}
  end
end
