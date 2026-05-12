defmodule HuddlzWeb.Components.Pill do
  @moduledoc """
  V3 status pill — small inline badge used for RSVP states, role tags, etc.
  """
  use Phoenix.Component

  attr :variant, :atom,
    values: [:default, :cyan, :warn, :magenta, :muted],
    default: :default

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pill(assigns) do
    ~H"""
    <span class={["pill", variant_class(@variant), @class]} {@rest}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp variant_class(:default), do: nil
  defp variant_class(:cyan), do: "cyan"
  defp variant_class(:warn), do: "warn"
  defp variant_class(:magenta), do: "magenta"
  defp variant_class(:muted), do: "muted"
end
