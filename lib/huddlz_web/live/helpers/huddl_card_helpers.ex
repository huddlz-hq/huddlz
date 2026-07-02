defmodule HuddlzWeb.Live.Helpers.HuddlCardHelpers do
  @moduledoc """
  Shared formatting helpers for huddl card listings (discover, my huddlz,
  group show): date block, `event_type` tag, and RSVP count labels.
  """

  def tag_variant(:in_person), do: :in_person
  def tag_variant(:virtual), do: :online
  def tag_variant(:hybrid), do: :hybrid

  def tag_label(:in_person), do: "In person"
  def tag_label(:virtual), do: "Online"
  def tag_label(:hybrid), do: "Hybrid"

  def huddl_month(%{starts_at: %DateTime{} = dt}),
    do: Calendar.strftime(dt, "%b") |> String.upcase()

  def huddl_day(%{starts_at: %DateTime{} = dt}), do: Calendar.strftime(dt, "%-d")

  def format_meta_when(%DateTime{} = dt) do
    "#{Calendar.strftime(dt, "%a")} · #{Calendar.strftime(dt, "%-I:%M %p")}"
  end

  def rsvp_label(%{rsvp_count: count, max_attendees: max}) when is_integer(max) and max > 0,
    do: "#{count} / #{max} RSVPs"

  def rsvp_label(%{rsvp_count: 1}), do: "1 RSVP"
  def rsvp_label(%{rsvp_count: count}), do: "#{count} RSVPs"
end
