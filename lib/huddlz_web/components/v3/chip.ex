defmodule HuddlzWeb.V3.Chip do
  @moduledoc """
  V3 filter chip — used in `chip-group` filter bars.

  Renders as a `<button>` by default; pass `href`/`navigate`/`patch` to
  render as a link instead.
  """
  use Phoenix.Component

  attr :active, :boolean, default: false
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(href navigate patch type phx-click phx-value-id phx-target name value)

  slot :inner_block, required: true

  def v3_chip(%{rest: rest} = assigns) do
    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={["chip", @active && "is-active", @class]} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      assigns = assign_new(assigns, :type, fn -> "button" end)

      ~H"""
      <button type={@type} class={["chip", @active && "is-active", @class]} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end
end
