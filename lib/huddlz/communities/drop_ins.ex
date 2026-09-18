defmodule Huddlz.Communities.DropIns do
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
  """

  alias Huddlz.Communities

  @type spot :: :going | :waitlisted | :rsvpd
  @type entry :: %{group: struct(), huddl: struct(), spot: spot()}

  @doc """
  Lists the actor's dropped-in groups. `opts[:load]` is passed to the group
  read.
  """
  @spec list(struct(), keyword()) :: {:ok, [entry()]} | {:error, term()}
  def list(actor, opts \\ []) do
    with {:ok, groups} <-
           Communities.groups_for_actor(:dropped_in,
             actor: actor,
             load: Keyword.get(opts, :load, []),
             page: false
           ),
         {:ok, spots} <- spots_for(groups, actor) do
      {:ok, entries(groups, spots)}
    end
  end

  defp spots_for([], _actor), do: {:ok, []}

  defp spots_for(groups, actor) do
    Communities.list_drop_in_spots(Enum.map(groups, & &1.id), actor: actor)
  end

  defp entries(groups, spots) do
    by_group = Enum.group_by(spots, & &1.huddl.group_id)

    groups
    |> Enum.flat_map(fn group ->
      case Map.get(by_group, group.id, []) do
        [] -> []
        group_spots -> [entry(group, group_spots)]
      end
    end)
    |> Enum.sort_by(& &1.latest_rsvp, {:desc, DateTime})
    |> Enum.map(&Map.delete(&1, :latest_rsvp))
  end

  defp entry(group, spots) do
    chosen = mention(spots)

    %{
      group: group,
      huddl: chosen.huddl,
      spot: spot(chosen),
      latest_rsvp: spots |> Enum.map(& &1.rsvped_at) |> Enum.max(DateTime)
    }
  end

  defp mention(spots) do
    {upcoming, completed} = Enum.split_with(spots, &(&1.huddl.lifecycle_state == :published))

    case Enum.sort_by(upcoming, & &1.huddl.starts_at, DateTime) do
      [soonest | _] -> soonest
      [] -> Enum.max_by(completed, & &1.huddl.starts_at, DateTime)
    end
  end

  defp spot(%{huddl: %{lifecycle_state: :completed}}), do: :rsvpd
  defp spot(%{waitlisted_at: nil}), do: :going
  defp spot(_waitlisted), do: :waitlisted
end
