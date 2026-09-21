defmodule Huddlz.Communities.GroupActivity.Calculations.DropInNote do
  @moduledoc """
  What an activity entry says about drop-ins, for the organizer's feed.

    * `note: :not_a_member_yet` — true on an RSVP by someone who has never
      belonged to the group. Someone who left is not "not a member yet".
    * `note: :rsvped_first` — on a join, the title of the latest huddl of
      the group the person RSVPd to before it while not a member, or nil.
      Accepted invitations say nothing: the invitation brought them.

  The feed already names everyone who RSVPs, so neither tells an organizer
  about anyone they could not already see.
  """
  use Ash.Resource.Calculation

  require Ash.Query

  alias Huddlz.Communities.{DropInHistory, Huddl}

  @impl true
  def load(_query, _opts, _context), do: [:kind, :group_id, :user_id, :occurred_at]

  @impl true
  def calculate(records, opts, context) do
    histories =
      records
      |> Enum.filter(&(&1.kind == kind(opts[:note])))
      |> Enum.group_by(& &1.group_id, & &1.user_id)
      |> Map.new(fn {group_id, user_ids} ->
        {group_id, DropInHistory.load(group_id, user_ids)}
      end)

    records
    |> Enum.map(&note(opts[:note], &1, histories[&1.group_id]))
    |> titles(opts[:note], context.actor)
  end

  defp kind(:not_a_member_yet), do: :rsvped
  defp kind(:rsvped_first), do: :joined

  defp note(:not_a_member_yet, %{kind: :rsvped} = entry, history),
    do: not DropInHistory.ever_member?(history, entry.user_id)

  defp note(:not_a_member_yet, _entry, _history), do: false

  defp note(:rsvped_first, %{kind: :joined} = entry, history) do
    case DropInHistory.latest_before(history, entry.user_id, entry.occurred_at) do
      %{huddl_id: huddl_id} -> huddl_id
      nil -> nil
    end
  end

  defp note(:rsvped_first, _entry, _history), do: nil

  defp titles(notes, :not_a_member_yet, _actor), do: notes

  # Read as the organizer asking, who can see every huddl of their group.
  # A huddl that is gone, or one the reader cannot see, leaves no note.
  defp titles(huddl_ids, :rsvped_first, actor) do
    ids = huddl_ids |> Enum.reject(&is_nil/1) |> Enum.uniq()

    titles =
      Huddl
      |> Ash.Query.filter(id in ^ids)
      |> Ash.Query.select([:id, :title])
      |> Ash.read!(actor: actor)
      |> Map.new(&{&1.id, &1.title})

    Enum.map(huddl_ids, &Map.get(titles, &1))
  end
end
