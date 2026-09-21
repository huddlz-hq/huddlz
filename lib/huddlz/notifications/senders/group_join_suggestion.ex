defmodule Huddlz.Notifications.Senders.GroupJoinSuggestion do
  @moduledoc """
  Sender for the join suggestion: the one email a drop-in gets about a
  group, about a day after a huddl they RSVPd to completes (ADR-0011).
  Activity category, so preferences and the unsubscribe footer apply.

  It says "RSVPd", never "came" or "went": huddlz knows who RSVPd, not who
  turned up (ADR-0003, ADR-0008). Up to three upcoming huddlz the recipient
  can see are listed; with none, it says so.

  Required payload keys:

    * `"huddl_id"` — the completed huddl they RSVPd to. The sender
      re-reads it, and the group with it, for current names.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @upcoming 3

  @impl true
  def build(user, payload) do
    huddl = fetch_huddl!(payload)
    group = huddl.group
    upcoming = upcoming_huddlz(group, user)

    Layout.email(%{
      to: user.email,
      subject: "Hear about #{group.name}'s next huddlz",
      kicker: to_string(group.name),
      title: "Hear about their next huddlz",
      paragraphs: [opening(huddl, group) | calendar_paragraph(upcoming)],
      facts: Enum.map(upcoming, &upcoming_fact/1),
      action:
        {"See #{group.name}", url(~p"/groups/#{group.slug}?#{[from: :join_suggestion_email]}")},
      aside:
        "This is the only time we'll suggest it for #{group.name}. " <>
          "Joining is one click on the group page, and leaving is just as easy.",
      footer: Footer.activity(user, :group_join_suggestion)
    })
  end

  defp opening(huddl, group) do
    [
      "You RSVPd to ",
      {:strong, huddl.title},
      " on #{day(huddl.starts_at, huddl.time_zone)}. #{group.name} hosted it, and you're not a member yet. " <>
        "Members hear when the group schedules a huddl, and the group sits on your groups page."
    ]
  end

  defp calendar_paragraph([]),
    do: ["Nothing is on their calendar yet. Join and you'll hear as soon as something is."]

  defp calendar_paragraph(_upcoming), do: ["Coming up:"]

  defp upcoming_fact(huddl) do
    {short_day(huddl.starts_at, huddl.time_zone), huddl.title, place(huddl)}
  end

  defp place(%{event_type: :virtual}), do: "Online"

  defp place(%{physical_location: location}) when is_binary(location) and location != "",
    do: location

  defp place(_huddl), do: nil

  defp upcoming_huddlz(group, user) do
    Communities.get_group_huddlz!(group.id, actor: user, query: [limit: @upcoming])
  end

  defp day(%DateTime{} = at, time_zone),
    do: at |> local(time_zone) |> Calendar.strftime("%A, %b %-d")

  defp short_day(%DateTime{} = at, time_zone),
    do: at |> local(time_zone) |> Calendar.strftime("%b %-d")

  defp local(at, time_zone) do
    case DateTime.shift_zone(at, time_zone || "Etc/UTC") do
      {:ok, shifted} -> shifted
      {:error, _} -> at
    end
  end

  defp fetch_huddl!(%{"huddl_id" => id}) when is_binary(id) do
    Ash.get!(Huddl, id, authorize?: false, load: [:group])
  end

  defp fetch_huddl!(_payload) do
    raise ArgumentError,
          "GroupJoinSuggestion requires payload key \"huddl_id\" with a binary UUID"
  end
end
