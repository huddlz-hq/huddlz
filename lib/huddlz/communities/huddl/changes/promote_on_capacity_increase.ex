defmodule Huddlz.Communities.Huddl.Changes.PromoteOnCapacityIncrease do
  @moduledoc """
  When organizers raise (or lift) `max_attendees`, promote enough
  waitlisted users to fill the newly available seats. Runs after the
  update so the new capacity is visible to the count math.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.WaitlistPromotion

  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :max_attendees) do
      Ash.Changeset.after_action(changeset, fn cs, huddl ->
        {:ok, WaitlistPromotion.fill_open_seats(huddl, Huddlz.Audit.nested_opts(cs))}
      end)
    else
      changeset
    end
  end
end
