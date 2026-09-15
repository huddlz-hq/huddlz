defmodule Huddlz.Communities.HuddlAttendee.Calculations.WaitlistPosition do
  @moduledoc """
  The current person's position on a waitlist. Counting earlier entries
  does not expose those people's identities or their attendance records.
  """
  use Ash.Resource.Calculation

  alias Huddlz.Communities.HuddlAttendee

  require Ash.Query

  @impl true
  def load(_query, _opts, _context), do: [:huddl_id, :user_id, :waitlisted_at]

  @impl true
  def calculate(records, _opts, %{actor: %{id: actor_id}}) do
    Enum.map(records, &position(&1, actor_id))
  end

  def calculate(records, _opts, _context), do: Enum.map(records, fn _ -> nil end)

  defp position(
         %{user_id: actor_id, waitlisted_at: %DateTime{} = at, huddl_id: huddl_id},
         actor_id
       ) do
    # A person can see their own rank without permission to read the waitlist.
    HuddlAttendee
    |> Ash.Query.filter(
      huddl_id == ^huddl_id and not is_nil(waitlisted_at) and waitlisted_at <= ^at
    )
    |> Ash.count!(authorize?: false)
  end

  defp position(_record, _actor_id), do: nil
end
