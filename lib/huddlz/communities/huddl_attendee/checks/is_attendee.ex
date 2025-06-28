defmodule Huddlz.Communities.HuddlAttendee.Checks.IsAttendee do
  @moduledoc """
  Check if the actor is also attending the huddl.
  Used to ensure only attendees can see other attendees.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.HuddlAttendee
  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor is attending this huddl"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  @impl true
  def match?(actor, context, _opts) do
    huddl_id = get_huddl_id(context)

    if huddl_id && actor do
      check_is_attendee(actor, huddl_id)
    else
      # For queries without a specific huddl, we can't check attendance
      false
    end
  end

  # Extract huddl_id from various contexts
  defp get_huddl_id(%{changeset: %{arguments: %{huddl_id: huddl_id}}}), do: huddl_id
  defp get_huddl_id(%{query: %{arguments: %{huddl_id: huddl_id}}}), do: huddl_id
  defp get_huddl_id(%{record: %{huddl_id: huddl_id}}), do: huddl_id
  defp get_huddl_id(_), do: nil

  # Check if the actor is attending this huddl
  defp check_is_attendee(%{id: user_id}, huddl_id) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl_id and user_id == ^user_id)
    |> Ash.exists?(authorize?: false)
  end
end
