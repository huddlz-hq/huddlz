defmodule HuddlzWeb.Components.TurnoutChart do
  @moduledoc """
  Turnout per huddl: for each past huddl, its RSVPs beside how many came,
  the room and the call stacked, with a capacity tick over the pair and a
  dashed outline reading "?" where no turnout was recorded. Inline SVG on
  the design tokens, server-rendered like the other charts.

  Readable back from the markup: each pair carries the huddl, its RSVPs,
  turnout and capacity as data attributes, and each bar its count.
  """
  use Phoenix.Component

  @height 300
  @left 36
  @right 20
  @top 20
  @bottom 34
  @bar_width 18
  @gap 4

  attr :id, :string, required: true

  attr :huddlz, :list,
    required: true,
    doc:
      "oldest first: maps with :id, :starts_at, :time_zone, :rsvp_count, :capacity, :counted?, :in_room, :on_call, :turnout"

  attr :width, :integer, default: 660, doc: "viewBox width"
  attr :class, :any, default: nil

  def turnout_chart(assigns) do
    assigns = assign(assigns, :chart, layout(assigns))

    ~H"""
    <svg
      id={@id}
      class={["chart turnout-chart", @class]}
      viewBox={"0 0 #{@chart.width} #{@chart.height}"}
      role="img"
      aria-label={description(@huddlz)}
      data-huddlz={length(@huddlz)}
    >
      <%= for {value, y, kind} <- @chart.gridlines do %>
        <line class={kind} x1={@chart.left} x2={@chart.right} y1={y} y2={y} />
        <text x={@chart.left - 8} y={y} text-anchor="end" dominant-baseline="middle">{value}</text>
      <% end %>

      <g
        :for={{huddl, slot} <- Enum.zip(@huddlz, @chart.slots)}
        class="pair"
        data-huddl={huddl.id}
        data-rsvps={huddl.rsvp_count}
        data-turnout={huddl.turnout}
        data-counted={to_string(huddl.counted?)}
        data-capacity={huddl.capacity}
      >
        <rect
          class="col rsvps"
          data-count={huddl.rsvp_count}
          x={slot.rsvps_x}
          y={slot.rsvps_y}
          width={@chart.bar_width}
          height={@chart.base - slot.rsvps_y}
          rx="3"
        />
        <text x={slot.rsvps_x + @chart.bar_width / 2} y={slot.rsvps_label_y} text-anchor="middle">
          {huddl.rsvp_count}
        </text>

        <line
          :if={huddl.capacity}
          class="cap"
          data-capacity={huddl.capacity}
          x1={slot.rsvps_x - 3}
          x2={slot.came_x + @chart.bar_width + 3}
          y1={slot.capacity_y}
          y2={slot.capacity_y}
        />

        <%= if huddl.counted? do %>
          <rect
            class="col room"
            data-count={huddl.in_room || 0}
            x={slot.came_x}
            y={slot.room_y}
            width={@chart.bar_width}
            height={@chart.base - slot.room_y}
            rx="3"
          />
          <rect
            :if={(huddl.on_call || 0) > 0}
            class="col call"
            data-count={huddl.on_call}
            x={slot.came_x}
            y={slot.came_y}
            width={@chart.bar_width}
            height={slot.room_y - slot.came_y}
            rx="3"
          />
          <text
            class="val"
            x={slot.came_x + @chart.bar_width / 2}
            y={slot.came_label_y}
            text-anchor="middle"
          >
            {huddl.turnout}
          </text>
        <% else %>
          <rect
            class="col none"
            x={slot.came_x}
            y={slot.rsvps_y}
            width={@chart.bar_width}
            height={@chart.base - slot.rsvps_y}
            rx="3"
          />
          <text
            class="val"
            x={slot.came_x + @chart.bar_width / 2}
            y={slot.rsvps_label_y}
            text-anchor="middle"
          >
            ?
          </text>
        <% end %>

        <text x={slot.x} y={@chart.height - 10} text-anchor="middle">{label(huddl)}</text>
      </g>
    </svg>
    """
  end

  defp layout(%{huddlz: huddlz, width: width}) do
    n = max(length(huddlz), 1)
    hi = ceiling(Enum.flat_map(huddlz, &[&1.rsvp_count, &1.turnout, &1.capacity]))
    plot_width = width - @left - @right
    plot_height = @height - @top - @bottom
    base = @top + plot_height
    slot_width = plot_width / n
    bar_width = min(@bar_width, Float.round(slot_width * 0.3, 1))
    y = fn v -> Float.round(@top + plot_height * (1 - (v || 0) / hi), 1) end

    slots =
      Enum.map(0..(n - 1), fn i ->
        x = Float.round(@left + slot_width * i + slot_width / 2, 1)
        huddl = Enum.at(huddlz, i)
        room = (huddl && huddl.in_room) || 0
        came = (huddl && huddl.turnout) || 0

        capacity_y = huddl && huddl.capacity && y.(huddl.capacity)
        rsvps_y = y.(huddl && huddl.rsvp_count)
        came_y = y.(came)

        %{
          x: x,
          rsvps_x: Float.round(x - bar_width - @gap / 2, 1),
          came_x: Float.round(x + @gap / 2, 1),
          rsvps_y: rsvps_y,
          rsvps_label_y: label_y(rsvps_y, capacity_y),
          capacity_y: capacity_y,
          room_y: y.(room),
          came_y: came_y,
          came_label_y: label_y(came_y, capacity_y)
        }
      end)

    %{
      width: width,
      height: @height,
      left: @left,
      right: width - @right,
      base: base,
      bar_width: bar_width,
      gridlines: [{0, y.(0), "axis"}, {div(hi, 2), y.(div(hi, 2)), "grid"}, {hi, y.(hi), "grid"}],
      slots: slots
    }
  end

  # A value sits just above its bar, or above the capacity tick when the
  # bar top is close enough that the two would collide.
  defp label_y(bar_y, nil), do: bar_y - 5
  defp label_y(bar_y, cap_y) when abs(bar_y - cap_y) < 12, do: min(bar_y, cap_y) - 5
  defp label_y(bar_y, _cap_y), do: bar_y - 5

  # The top gridline: the largest value rounded up to something round.
  defp ceiling(values) do
    max = values |> Enum.reject(&is_nil/1) |> Enum.max(fn -> 0 end)

    cond do
      max <= 5 -> 5
      max <= 10 -> 10
      max <= 50 -> div(max + 4, 5) * 5
      true -> div(max + 9, 10) * 10
    end
  end

  defp label(%{starts_at: starts_at, time_zone: time_zone}) do
    starts_at |> DateTime.shift_zone!(time_zone) |> Calendar.strftime("%b %-d")
  end

  defp description(huddlz) do
    counted = Enum.count(huddlz, & &1.counted?)
    "RSVPs and turnout for the last #{length(huddlz)} huddlz, #{counted} counted"
  end
end
