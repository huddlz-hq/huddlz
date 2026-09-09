defmodule HuddlzWeb.Components.Card do
  @moduledoc """
  V3 card — anchor card used for huddlz, groups, and saved items in grid views.

  Slot-driven so callers can compose cover image, date stamp, tag, body, and
  foot independently.
  """
  use Phoenix.Component

  import HuddlzWeb.Components.CoverImage

  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
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
      <div :if={@cover != []} class="card-cover">
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

  @skeleton_shapes [
    %{group: 40, title: 85, second: 55, meta: 70},
    %{group: 55, title: 70, second: nil, meta: 70},
    %{group: 40, title: 85, second: 40, meta: 55}
  ]

  @doc """
  Renders placeholder cards sharing the huddl card's anatomy for a grid whose
  results are still on their way. The grid fades in after a short delay so a
  fast search never flashes it.
  """
  attr :label, :string, required: true, doc: "accessible name for the busy region"
  attr :count, :integer, default: 3

  def card_skeleton_grid(assigns) do
    shapes = @skeleton_shapes |> Stream.cycle() |> Enum.take(assigns.count)
    assigns = assign(assigns, :shapes, shapes)

    ~H"""
    <div class="grid grid-skeleton" role="status" aria-busy="true" aria-label={@label}>
      <div :for={shape <- @shapes} class="card is-skeleton" aria-hidden="true">
        <div class="card-cover skel"></div>
        <div class="card-body">
          <span class="skel skel-line" style={"--w: #{shape.group}%"}></span>
          <span class="skel skel-line skel-title" style={"--w: #{shape.title}%"}></span>
          <span :if={shape.second} class="skel skel-line skel-title" style={"--w: #{shape.second}%"}></span>
          <span class="skel skel-line skel-meta" style={"--w: #{shape.meta}%"}></span>
        </div>
        <div class="card-foot">
          <span class="skel skel-pill"></span>
          <span class="skel skel-line skel-note"></span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders group cover media over a neutral fallback, a `panel-2` field with
  the group's initials in a tile, that stays visible when the image is absent
  or cannot be loaded.
  """
  attr :group, :map, required: true
  attr :id, :string, required: true
  attr :variant, :atom, values: [:card, :hero, :thumb], default: :card

  def group_cover(assigns) do
    assigns = assign(assigns, :initials, group_initials(assigns.group.name))

    ~H"""
    <div id={@id} class={["group-cover", "group-cover--#{@variant}"]} data-testid="group-cover">
      <div class="group-cover-fallback" aria-hidden="true">
        <span class="group-cover-signal">{@initials}</span>
      </div>
      <.cover_image
        :if={@group.current_image_url}
        id={"#{@id}-image"}
        class="group-cover-image"
        image_url={@group.current_image_url}
      />
    </div>
    """
  end

  @doc """
  Renders the neutral cover shown when a huddl has no image: a 16:9 tile in
  `panel-2` carrying the group's initials (used inside a `<:cover>` slot of
  `card`).
  """
  attr :name, :string, required: true, doc: "group name the initials are taken from"

  def cover_fallback(assigns) do
    assigns = assign(assigns, :initials, group_initials(assigns.name))

    ~H"""
    <div class="card-cover-fallback" aria-hidden="true">
      <span>{@initials}</span>
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

  @doc """
  Initials for a group name, accepting the `Ash.CiString` the resource
  stores as well as a plain string. Shared by the sidebar, covers and the
  huddl page hero.
  """
  def group_initials(nil), do: "??"

  def group_initials(name) do
    name
    |> to_string()
    |> String.trim()
    |> String.split(~r/[\s\-_]+/, trim: true)
    |> case do
      [] -> "??"
      [single] -> single |> String.slice(0, 2) |> String.upcase()
      [first, second | _] -> String.upcase(String.first(first) <> String.first(second))
    end
  end
end
