defmodule HuddlzWeb.Components.GrowthChart do
  @moduledoc """
  Member growth over a period: a line of members at each bucket's end
  above a strip of bars for how many joined in each bucket. Inline SVG
  on the design tokens, server-rendered like the sparkline.

  Readable back from the markup: the line and the bar strip carry their
  values in `data-points`, each dot and bar its bucket label and value,
  and the root the bucket unit and count.
  """
  use Phoenix.Component

  @left 36
  @right 20
  @top 26
  @bar_width 26
  @wide %{line_height: 140, bar_gap: 26, bar_height: 44, bottom: 30}
  @compact %{line_height: 110, bar_gap: 22, bar_height: 32, bottom: 26}
  @compact_label_limit 8

  attr :id, :string, required: true
  attr :unit, :atom, required: true, values: [:month, :fortnight, :week]

  attr :buckets, :list,
    required: true,
    doc: "maps with :label, :members (at the bucket's end) and :joined (inside it)"

  attr :width, :integer, default: 720, doc: "viewBox width"

  attr :compact, :boolean,
    default: false,
    doc: "a shorter chart that labels every other bucket when there are many"

  attr :class, :any, default: nil

  def growth_chart(assigns) do
    assigns = assign(assigns, :chart, layout(assigns))

    ~H"""
    <svg
      id={@id}
      class={["chart growth-chart", @class]}
      viewBox={"0 0 #{@chart.width} #{@chart.height}"}
      role="img"
      aria-label={description(@buckets, @unit)}
      data-unit={@unit}
      data-buckets={length(@buckets)}
    >
      <%= for {value, y} <- @chart.gridlines do %>
        <line class="grid" x1={@chart.left} x2={@chart.right} y1={y} y2={y} />
        <text x={@chart.left - 8} y={y} text-anchor="end" dominant-baseline="middle">{value}</text>
      <% end %>

      <path class="area" d={@chart.area_path} />
      <polyline
        id={"#{@id}-line"}
        class="line"
        data-points={Enum.map_join(@buckets, ",", & &1.members)}
        points={@chart.line_path}
      />
      <circle
        :for={{bucket, {x, y}} <- Enum.zip(@buckets, @chart.line_points)}
        class="dot"
        data-label={bucket.label}
        data-members={bucket.members}
        cx={x}
        cy={y}
        r="3.5"
      />
      <text
        class="callout"
        x={@chart.callout_x}
        y={@chart.callout_y}
        text-anchor={@chart.callout_anchor}
      >
        {List.last(@buckets).members} members
      </text>

      <line class="axis" x1={@chart.left} x2={@chart.right} y1={@chart.bar_base} y2={@chart.bar_base} />
      <g id={"#{@id}-bars"} data-points={Enum.map_join(@buckets, ",", & &1.joined)}>
        <%= for {bucket, {x, height}} <- Enum.zip(@buckets, @chart.bars) do %>
          <rect
            class="col"
            data-label={bucket.label}
            data-joined={bucket.joined}
            x={x - @chart.bar_width / 2}
            y={@chart.bar_base - height}
            width={@chart.bar_width}
            height={height}
            rx="3"
          />
          <text
            :if={@chart.bar_values?}
            class="val"
            x={x}
            y={@chart.bar_base - height - 5}
            text-anchor="middle"
          >
            {joined_label(bucket.joined)}
          </text>
        <% end %>
      </g>

      <text
        :for={{label, x} <- @chart.labels}
        x={x}
        y={@chart.height - 6}
        text-anchor="middle"
      >
        {label}
      </text>
    </svg>
    """
  end

  defp layout(%{buckets: buckets, width: width, compact: compact}) do
    dims = if compact, do: @compact, else: @wide
    n = length(buckets)
    members = Enum.map(buckets, & &1.members)
    joined = Enum.map(buckets, & &1.joined)
    {lo, hi, step} = scale(members)
    plot_width = width - @left - @right
    bar_base = @top + dims.line_height + dims.bar_gap + dims.bar_height
    x = fn i -> Float.round(@left + i * plot_width / max(n - 1, 1), 1) end
    y = fn v -> Float.round(@top + dims.line_height * (1 - (v - lo) / (hi - lo)), 1) end
    line_points = members |> Enum.with_index() |> Enum.map(fn {v, i} -> {x.(i), y.(v)} end)
    line_path = Enum.map_join(line_points, " ", fn {px, py} -> "#{px},#{py}" end)
    {last_x, last_y} = List.last(line_points)
    most_joined = max(Enum.max(joined), 1)

    crowded? = compact and n > @compact_label_limit

    %{
      width: width,
      height: bar_base + dims.bottom,
      left: @left,
      right: width - @right,
      gridlines: Enum.map(lo..hi//step, fn v -> {v, y.(v)} end),
      line_path: line_path,
      line_points: line_points,
      area_path:
        "M#{x.(0)},#{y.(lo)} L#{String.replace(line_path, " ", " L")} L#{x.(n - 1)},#{y.(lo)} Z",
      callout_x: last_x - 10,
      callout_y: last_y - 12,
      callout_anchor: "end",
      bar_base: bar_base,
      bar_width: min(@bar_width, Float.round(plot_width / n * 0.6, 1)),
      bar_values?: not crowded?,
      bars:
        joined
        |> Enum.with_index()
        |> Enum.map(fn {v, i} -> {x.(i), Float.round(dims.bar_height * v / most_joined, 1)} end),
      labels: labels(buckets, x, crowded?)
    }
  end

  # Every bucket's label, or every other one from the newest back when
  # the chart is too narrow for them all.
  defp labels(buckets, x, crowded?) do
    n = length(buckets)

    buckets
    |> Enum.with_index()
    |> Enum.filter(fn {_bucket, i} -> not crowded? or rem(n - 1 - i, 2) == 0 end)
    |> Enum.map(fn {bucket, i} -> {bucket.label, x.(i)} end)
  end

  # A scale for the line: a round step so that the members fit within
  # a few gridlines, from a round floor to a round ceiling.
  defp scale(members) do
    lo = Enum.min(members)
    hi = Enum.max(members)
    step = nice_step(max(hi - lo, 1) / 2)
    floor = max(div(lo, step) * step, 0)
    ceiling = max(div(hi + step - 1, step) * step, floor + step)
    {floor, ceiling, step}
  end

  defp nice_step(raw) do
    magnitude = :math.pow(10, floor(:math.log10(max(raw, 1))))

    Enum.find_value([1, 2, 5, 10], fn m ->
      step = round(m * magnitude)
      if step >= raw, do: step
    end)
  end

  defp joined_label(0), do: "0"
  defp joined_label(n), do: "+#{n}"

  defp description(buckets, unit) do
    gained = buckets |> Enum.map(& &1.joined) |> Enum.sum()
    "#{List.last(buckets).members} members, #{gained} joined over #{length(buckets)} #{unit}s"
  end
end
