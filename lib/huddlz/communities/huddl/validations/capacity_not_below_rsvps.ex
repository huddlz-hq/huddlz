defmodule Huddlz.Communities.Huddl.Validations.CapacityNotBelowRsvps do
  @moduledoc """
  Prevents organizers from reducing capacity below the current RSVP count.
  """

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute
  alias Huddlz.Communities.HuddlAttendee

  require Ash.Query

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def describe(_opts) do
    [message: "cannot be less than the current RSVP count", vars: []]
  end

  @impl true
  def validate(changeset, _opts, _context) do
    with true <- changeset.action.name == :update,
         true <- Ash.Changeset.changing_attribute?(changeset, :max_attendees),
         max_attendees when not is_nil(max_attendees) <-
           Ash.Changeset.get_attribute(changeset, :max_attendees),
         rsvp_count <- current_rsvp_count(changeset.data.id),
         true <- max_attendees < rsvp_count do
      {:error,
       InvalidAttribute.exception(
         field: :max_attendees,
         message: "cannot be less than the current RSVP count"
       )}
    else
      _ -> :ok
    end
  end

  defp current_rsvp_count(huddl_id) do
    HuddlAttendee
    |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl_id})
    |> Ash.count!(authorize?: false)
  end
end
