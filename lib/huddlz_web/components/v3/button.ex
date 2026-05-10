defmodule HuddlzWeb.V3.Button do
  @moduledoc """
  V3 button — `btn-primary` (cyan fill, one per surface) or `btn-secondary`
  (outline). Renders a `<button>` by default; pass `href`/`navigate`/`patch`
  to render a `<.link>`.

  Variants:

    * `:primary` — headline action, cyan fill
    * `:secondary` — outline (default)
    * `:muted` — outline with muted text colour
    * `:destructive` — outline using the warn/error colour
  """
  use Phoenix.Component

  attr :variant, :atom,
    values: [:primary, :secondary, :muted, :destructive],
    default: :secondary

  attr :type, :string, default: "button"
  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(href navigate patch disabled name value form)

  slot :inner_block, required: true

  def v3_button(%{rest: rest} = assigns) do
    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={[base_class(@variant), @class]} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button type={@type} class={[base_class(@variant), @class]} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  defp base_class(:primary), do: "btn-primary"
  defp base_class(:secondary), do: "btn-secondary"
  defp base_class(:muted), do: "btn-secondary muted-btn"
  defp base_class(:destructive), do: "btn-secondary destructive-btn"
end
