defmodule HuddlzWeb.V3.Card do
  @moduledoc """
  V3 card — anchor card used for huddlz, groups, and saved items in grid views.

  Slot-driven so callers can compose cover image, date stamp, tag, body, and
  foot independently. The default `gradient` cycles through 1–6 to vary cover
  fallbacks across a list.
  """
  use Phoenix.Component

  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil

  attr :gradient, :integer,
    values: [1, 2, 3, 4, 5, 6],
    default: 1,
    doc: "1–6 selects the cover fallback gradient"

  attr :class, :any, default: nil
  attr :rest, :global

  slot :cover, doc: "cover content (img, date stamp, card-tag)"
  slot :body, required: true, doc: "card body — group label, title, meta"
  slot :foot, doc: "optional card foot — pill + relative time"

  def v3_card(assigns) do
    ~H"""
    <.link
      href={@href}
      navigate={@navigate}
      patch={@patch}
      class={["card", @class]}
      {@rest}
    >
      <div :if={@cover != []} class={"card-cover gradient-#{@gradient}"}>
        {render_slot(@cover)}
      </div>
      <div class="card-body">
        {render_slot(@body)}
      </div>
      <div :if={@foot != []} class="card-foot">
        {render_slot(@foot)}
      </div>
    </.link>
    """
  end

  @doc """
  Renders a date stamp (used inside a `<:cover>` slot of `v3_card`).
  """
  attr :month, :string, required: true, doc: "3-letter month abbreviation, uppercase"
  attr :day, :any, required: true, doc: "day of month"

  def v3_date_stamp(assigns) do
    ~H"""
    <div class="date-stamp">
      <span class="m">{@month}</span>
      <span class="d">{@day}</span>
    </div>
    """
  end

  @doc """
  Renders a card type tag (used inside a `<:cover>` slot of `v3_card`).

  Variants: `:in_person`, `:online`, `:hybrid`.
  """
  attr :variant, :atom, values: [:in_person, :online, :hybrid], required: true
  slot :inner_block, required: true

  def v3_card_tag(assigns) do
    ~H"""
    <span class={["card-tag", tag_class(@variant)]}>{render_slot(@inner_block)}</span>
    """
  end

  defp tag_class(:in_person), do: "in-person"
  defp tag_class(:online), do: "online"
  defp tag_class(:hybrid), do: "hybrid"
end
