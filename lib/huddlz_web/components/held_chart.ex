defmodule HuddlzWeb.Components.HeldChart do
  @moduledoc """
  Huddlz held over a period: a bar per bucket with its value above it,
  and the huddlz cancelled in that bucket as a dashed outline stacked on
  top. Inline SVG on the design tokens, server-rendered like the other
  charts.

  Readable back from the markup: each bar carries its bucket label and
  count, and the root the bucket unit and count.
  """
  use Phoenix.Component

  @height 270
  @left 36
  @right 20
  @top 20
  @bottom 34
  @gridlines 3

  attr :id, :string, required: true
  attr :unit, :atom, required: true, values: [:month, :fortnight, :week]

  attr :buckets, :list,
    required: true,
    doc: "maps with :label, :held and :cancelled"

  attr :width, :integer, default: 660, doc: "viewBox width"
  attr :compact, :boolean, default: false, doc: "narrower bars for a phone-width chart"
  attr :class, :any, default: nil

  def held_chart(assigns) do
    assigns = assign(assigns, :chart, layout(assigns))

    ~H"""
    <svg
      id={@id}
      class={["chart held-chart", @class]}
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
      <line class="axis" x1={@chart.left} x2={@chart.right} y1={@chart.base} y2={@chart.base} />

      <%= for {bucket, slot} <- Enum.zip(@buckets, @chart.slots) do %>
        <rect
          class="col room"
          data-label={bucket.label}
          data-held={bucket.held}
          x={slot.x - @chart.bar_width / 2}
          y={@chart.base - slot.held}
          width={@chart.bar_width}
          height={slot.held}
          rx="3"
        />
        <rect
          :if={bucket.cancelled > 0}
          class="col none"
          data-label={bucket.label}
          data-cancelled={bucket.cancelled}
          x={slot.x - @chart.bar_width / 2}
          y={@chart.base - slot.held - slot.cancelled}
          width={@chart.bar_width}
          height={slot.cancelled}
          rx="3"
        />
        <text
          class="val"
          x={slot.x}
          y={@chart.base - slot.held - slot.cancelled - 6}
          text-anchor="middle"
        >
          {bucket.held}
        </text>
        <text x={slot.x} y={@chart.height - 8} text-anchor="middle">{bucket.label}</text>
      <% end %>
    </svg>
    """
  end

  defp layout(%{buckets: buckets, width: width, compact: compact}) do
    n = max(length(buckets), 1)
    base = @height - @bottom
    plot_height = base - @top
    plot_width = width - @left - @right
    step = plot_width / n
    {ceiling, grid_step} = scale(Enum.map(buckets, &(&1.held + &1.cancelled)))
    y = fn v -> Float.round(plot_height * v / ceiling, 1) end

    %{
      width: width,
      height: @height,
      left: @left,
      right: width - @right,
      base: base,
      bar_width: min(if(compact, do: 30, else: 34), Float.round(step * 0.6, 1)),
      gridlines:
        Enum.map(grid_step..ceiling//grid_step, fn v -> {v, Float.round(base - y.(v), 1)} end),
      slots:
        buckets
        |> Enum.with_index()
        |> Enum.map(fn {bucket, i} ->
          %{
            x: Float.round(@left + step * (i + 0.5), 1),
            held: y.(bucket.held),
            cancelled: y.(bucket.cancelled)
          }
        end)
    }
  end

  # A round ceiling a few gridlines above the tallest bar.
  defp scale(values) do
    most = max(Enum.max(values, fn -> 0 end), 1)
    step = nice_step(most / @gridlines)
    {div(most + step - 1, step) * step, step}
  end

  defp nice_step(raw) do
    magnitude = :math.pow(10, floor(:math.log10(max(raw, 1))))

    Enum.find_value([1, 2, 5, 10], fn m ->
      step = round(m * magnitude)
      if step >= raw, do: step
    end)
  end

  defp description(buckets, unit) do
    held = buckets |> Enum.map(& &1.held) |> Enum.sum()
    cancelled = buckets |> Enum.map(& &1.cancelled) |> Enum.sum()
    "#{held} huddlz held over #{length(buckets)} #{unit}s, #{cancelled} cancelled"
  end
end
