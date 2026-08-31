defmodule HuddlzWeb.Components.HuddlCard do
  @moduledoc """
  Canonical compact card for a huddl across listing surfaces.
  """

  use Phoenix.Component

  import HuddlzWeb.Live.Helpers.HuddlCardHelpers

  alias HuddlzWeb.Components.Card
  alias HuddlzWeb.Components.HuddlCoverImage
  alias HuddlzWeb.Components.Pill

  attr :huddl, :map, required: true
  attr :id, :string, required: true
  attr :cover_id, :string, default: nil
  attr :gradient, :integer, values: [1, 2, 3, 4, 5, 6], default: 1
  attr :relationship_label, :string, default: nil
  attr :relationship_variant, :atom, default: :default
  attr :relationship_testid, :string, default: "huddl-relationship"
  attr :secondary_label, :string, default: nil
  attr :when_label, :string, default: nil

  def shared_huddl_card(assigns) do
    ~H"""
    <Card.card
      id={@id}
      navigate={"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}"}
      gradient={@gradient}
      data-starts-at={DateTime.to_iso8601(@huddl.starts_at)}
    >
      <:cover>
        <HuddlCoverImage.huddl_cover_image
          :if={@huddl.display_image_url}
          id={@cover_id || "#{@id}-cover"}
          class="card-cover-img"
          image_url={@huddl.display_image_url}
        />
        <Card.date_stamp month={huddl_month(@huddl)} day={huddl_day(@huddl)} />
        <Card.card_tag variant={tag_variant(@huddl.event_type)}>
          {tag_label(@huddl.event_type)}
        </Card.card_tag>
      </:cover>
      <:body>
        <span :if={@huddl.group} class="card-group">{@huddl.group.name}</span>
        <h3 class="card-title">{@huddl.title}</h3>
        <div class="card-meta">
          <span data-testid="huddl-when">{@when_label || format_meta_when(@huddl.starts_at)}</span>
          <%= if location_label(@huddl) do %>
            <span class="dot"></span>
            <span class="card-location">{location_label(@huddl)}</span>
          <% end %>
          <%= if @huddl.rsvp_count > 0 || @huddl.max_attendees do %>
            <span class="dot"></span>
            <span>{rsvp_label(@huddl)}</span>
          <% end %>
        </div>
      </:body>
      <:foot :if={@relationship_label}>
        <Pill.pill variant={@relationship_variant} data-testid={@relationship_testid}>
          {@relationship_label}
        </Pill.pill>
        <span :if={@secondary_label} class="muted text-xs">
          {@secondary_label}
        </span>
      </:foot>
    </Card.card>
    """
  end

  defp location_label(%{group_location: %{name: name}}) when is_binary(name), do: name
  defp location_label(_huddl), do: nil
end
