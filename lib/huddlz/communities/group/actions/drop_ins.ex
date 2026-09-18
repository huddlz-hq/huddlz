defmodule Huddlz.Communities.Group.Actions.DropIns do
  @moduledoc """
  The groups a person has dropped in on, each with the huddl worth
  mentioning: "You're going to Long Run on Sep 20".

  Which groups qualify is decided in one place, Group's `:groups_for_actor`
  read with `relationship: :dropped_in` (ADR-0011). This module only pairs
  each of those groups with one of the person's own spots:

    * an upcoming huddl beats a completed one, soonest first, because what is
      coming is more useful than what has been;
    * otherwise the most recently completed huddl they held an RSVP at.

  Groups come back newest activity first, by the person's latest RSVP there.
  huddlz knows who RSVPd, not who came, so a completed huddl is `:rsvpd`,
  never "went" (ADR-0003, ADR-0008).

  Nothing here decides whether a spot counts: the two reads already have.
  The end time is consulted only for wording, because a huddl that is over
  stays published until the completion job records it, and "You're going to"
  would be wrong for it.
  """

  use Ash.Resource.Actions.Implementation

  alias Huddlz.Communities

  @impl true
  def run(input, _opts, %{actor: actor}) do
    with {:ok, groups} <-
           Communities.groups_for_actor(:dropped_in,
             actor: actor,
             load: [:current_image_url],
             page: false
           ),
         {:ok, spots} <- spots_for(groups, actor) do
      entries = entries(groups, spots)
      limit = Ash.ActionInput.get_argument(input, :limit)
      {:ok, %{entries: limit_entries(entries, limit), count: length(entries)}}
    end
  end

  defp limit_entries(entries, nil), do: entries
  defp limit_entries(entries, limit), do: Enum.take(entries, limit)

  defp spots_for([], _actor), do: {:ok, []}

  defp spots_for(groups, actor) do
    Communities.list_drop_in_spots(Enum.map(groups, & &1.id), actor: actor)
  end

  defp entries(groups, spots) do
    now = DateTime.utc_now()

    by_group = Enum.group_by(spots, & &1.huddl.group_id)

    groups
    |> Enum.flat_map(fn group ->
      case Map.get(by_group, group.id, []) do
        [] -> []
        group_spots -> [entry(group, group_spots, now)]
      end
    end)
    |> Enum.sort_by(& &1.latest_rsvp, {:desc, DateTime})
    |> Enum.map(&Map.delete(&1, :latest_rsvp))
  end

  defp entry(group, spots, now) do
    chosen = mention(spots, now)

    %{
      group: group,
      huddl: chosen.huddl,
      spot: spot(chosen, now),
      latest_rsvp: spots |> Enum.map(& &1.rsvped_at) |> Enum.max(DateTime)
    }
  end

  defp mention(spots, now) do
    {completed, upcoming} = Enum.split_with(spots, &ended?(&1.huddl, now))

    case Enum.sort_by(upcoming, & &1.huddl.starts_at, DateTime) do
      [soonest | _] -> soonest
      [] -> Enum.max_by(completed, & &1.huddl.starts_at, DateTime)
    end
  end

  defp spot(spot, now) do
    if ended?(spot.huddl, now), do: :rsvpd, else: spot(spot)
  end

  defp ended?(%{lifecycle_state: :completed}, _now), do: true
  defp ended?(huddl, now), do: DateTime.compare(huddl.ends_at, now) != :gt

  defp spot(%{waitlisted_at: nil}), do: :going
  defp spot(_waitlisted), do: :waitlisted
end
