defmodule HuddlzWeb.Components.SignupChart do
  @moduledoc """
  The next huddl's signup curve: RSVPs by day since it was published,
  drawn as inline SVG on the design tokens. Behind it, optionally, the
  group's typical curve (dashed) and the capacity (dotted).

  Server-rendered like the sparkline, and readable back the same way:
  each line carries its points in `data-points`.
  """
  use Phoenix.Component

  @width 600
  @height 200
  @left 32
  @right 16
  @top 14
  @bottom 28

  attr :id, :string, required: true
  attr :curve, :list, required: true, doc: "RSVPs standing at the end of each day since publish"
  attr :typical, :list, default: nil, doc: "the group's typical curve over the same days, or nil"
  attr :capacity, :integer, default: nil

  def signup_chart(assigns) do
    assigns = assign(assigns, :chart, layout(assigns))

    ~H"""
    <svg
      class="chart signup-chart"
      viewBox={"0 0 #{@chart.width} #{@chart.height}"}
      role="img"
      aria-label={description(@curve, @capacity)}
    >
      <%= for {value, y, kind} <- @chart.gridlines do %>
        <line class={kind} x1={@chart.left} x2={@chart.right} y1={y} y2={y} />
        <text x={@chart.left - 8} y={y} text-anchor="end" dominant-baseline="middle">{value}</text>
      <% end %>

      <%= if @capacity do %>
        <line
          id={"#{@id}-capacity"}
          class="cap"
          stroke-dasharray="2 3"
          data-capacity={@capacity}
          x1={@chart.left}
          x2={@chart.right}
          y1={@chart.capacity_y}
          y2={@chart.capacity_y}
        />
        <text x={@chart.right} y={@chart.capacity_y - 7} text-anchor="end">cap {@capacity}</text>
      <% end %>

      <polyline
        :if={@typical}
        id={"#{@id}-typical"}
        class="typical"
        data-points={Enum.join(@typical, ",")}
        points={@chart.typical_path}
      />

      <path class="area" d={@chart.area_path} />
      <polyline
        id={"#{@id}-curve"}
        class="line"
        data-points={Enum.join(@curve, ",")}
        data-days={length(@curve) - 1}
        points={@chart.curve_path}
      />
      <circle class="dot" cx={@chart.last_x} cy={@chart.last_y} r="3.5" />

      <text
        :for={{label, x, anchor} <- @chart.day_labels}
        x={x}
        y={@chart.height - 8}
        text-anchor={anchor}
      >
        {label}
      </text>
    </svg>
    """
  end

  defp layout(%{curve: curve, typical: typical, capacity: capacity}) do
    n = length(curve)
    hi = ceiling([capacity | curve ++ (typical || [])])
    plot_width = @width - @left - @right
    plot_height = @height - @top - @bottom
    x = fn i -> Float.round(@left + i * plot_width / max(n - 1, 1), 1) end
    y = fn v -> Float.round(@top + plot_height * (1 - v / hi), 1) end

    points = fn values ->
      values |> Enum.with_index() |> Enum.map_join(" ", fn {v, i} -> "#{x.(i)},#{y.(v)}" end)
    end

    %{
      width: @width,
      height: @height,
      left: @left,
      right: @width - @right,
      gridlines: gridlines(hi, y),
      capacity_y: capacity && y.(capacity),
      typical_path: typical && points.(typical),
      curve_path: points.(curve),
      area_path:
        "M#{x.(0)},#{y.(0)} L#{String.replace(points.(curve), " ", " L")} L#{x.(n - 1)},#{y.(0)} Z",
      last_x: x.(n - 1),
      last_y: y.(List.last(curve)),
      day_labels: day_labels(n - 1, x)
    }
  end

  # The top gridline: the largest value rounded up to something round.
  defp ceiling(values) do
    max = values |> Enum.reject(&is_nil/1) |> Enum.max(fn -> 0 end) |> ceil()

    cond do
      max <= 5 -> 5
      max <= 10 -> 10
      max <= 50 -> div(max + 4, 5) * 5
      true -> div(max + 9, 10) * 10
    end
  end

  defp gridlines(hi, y) do
    [{0, :axis}, {div(hi, 2), :grid}, {hi, :grid}]
    |> Enum.map(fn {value, kind} -> {value, y.(value), kind} end)
  end

  defp day_labels(0, x), do: [{"published today", x.(0), "start"}]

  defp day_labels(days, x) when days < 4,
    do: [{"published", x.(0), "start"}, {"today", x.(days), "end"}]

  defp day_labels(days, x) do
    mid = div(days, 2)
    [{"published", x.(0), "start"}, {"day #{mid}", x.(mid), "middle"}, {"today", x.(days), "end"}]
  end

  defp description(curve, nil),
    do: "#{List.last(curve)} RSVPs over #{length(curve)} days since publish"

  defp description(curve, capacity),
    do: "#{List.last(curve)} of #{capacity} RSVPs over #{length(curve)} days since publish"
end
