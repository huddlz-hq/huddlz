defmodule HuddlzWeb.Components.Card do
  @moduledoc """
  V3 card — anchor card used for huddlz, groups, and saved items in grid views.

  Slot-driven so callers can compose cover image, date stamp, tag, body, and
  foot independently. The default `gradient` cycles through 1–6 to vary cover
  fallbacks across a list.
  """
  use Phoenix.Component

  alias Huddlz.Storage.GroupImages

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

  def card(assigns) do
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
  Renders group cover media with a branded fallback that remains visible when
  the image is absent or cannot be loaded.
  """
  attr :group, :map, required: true
  attr :id, :string, required: true
  attr :variant, :atom, values: [:card, :hero, :thumb], default: :card

  attr :gradient, :integer,
    values: [1, 2, 3, 4, 5, 6],
    default: 1,
    doc: "1–6 selects the fallback gradient"

  def group_cover(assigns) do
    assigns = assign(assigns, :initials, group_initials(assigns.group.name))

    ~H"""
    <div
      id={@id}
      class={["group-cover", "group-cover--#{@variant}", "gradient-#{@gradient}"]}
      data-testid="group-cover"
    >
      <div class="group-cover-fallback" aria-hidden="true">
        <span class="group-cover-signal">{@initials}</span>
        <span :if={@variant != :thumb} class="group-cover-label">huddlz group</span>
      </div>
      <img
        :if={@group.current_image_url}
        id={"#{@id}-image"}
        class="group-cover-image"
        src={GroupImages.url(@group.current_image_url)}
        alt=""
        phx-hook="ImageFallback"
      />
    </div>
    """
  end

  @doc """
  Renders a date stamp (used inside a `<:cover>` slot of `card`).
  """
  attr :month, :string, required: true, doc: "3-letter month abbreviation, uppercase"
  attr :day, :any, required: true, doc: "day of month"

  def date_stamp(assigns) do
    ~H"""
    <div class="date-stamp">
      <span class="m">{@month}</span>
      <span class="d">{@day}</span>
    </div>
    """
  end

  @doc """
  Renders a card type tag (used inside a `<:cover>` slot of `card`).

  Variants: `:in_person`, `:online`, `:hybrid`.
  """
  attr :variant, :atom, values: [:in_person, :online, :hybrid], required: true
  slot :inner_block, required: true

  def card_tag(assigns) do
    ~H"""
    <span class={["card-tag", tag_class(@variant)]}>{render_slot(@inner_block)}</span>
    """
  end

  defp tag_class(:in_person), do: "in-person"
  defp tag_class(:online), do: "online"
  defp tag_class(:hybrid), do: "hybrid"

  defp group_initials(name) do
    name
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
