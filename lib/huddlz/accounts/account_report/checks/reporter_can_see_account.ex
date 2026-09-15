defmodule Huddlz.Accounts.AccountReport.Checks.ReporterCanSeeAccount do
  @moduledoc """
  Reporting grants no new visibility: the reporter must already meet the
  account on an ordinary member surface. That is a group they both belong
  to, or a huddl they both go to, or a huddl the reporter goes to that
  the account organizes, or a public huddl whose organizer they can see.
  Nobody reports themselves.
  """

  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.{GroupMember, Huddl, HuddlAttendee}

  require Ash.Query

  @impl true
  def describe(_opts), do: "the reporter can already see the account"

  @impl true
  def match?(%{id: actor_id}, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    case Ash.Changeset.get_attribute(changeset, :reported_user_id) do
      nil -> false
      ^actor_id -> false
      reported_id -> visible?(actor_id, reported_id)
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp visible?(actor_id, reported_id) do
    shares_group?(actor_id, reported_id) or
      shares_huddl?(actor_id, reported_id) or
      organizes_attended_huddl?(actor_id, reported_id) or
      organizes_public_huddl?(reported_id)
  end

  defp shares_group?(actor_id, reported_id) do
    GroupMember
    |> Ash.Query.filter(
      user_id == ^reported_id and exists(group.group_members, user_id == ^actor_id)
    )
    |> Ash.exists?(authorize?: false)
  end

  defp shares_huddl?(actor_id, reported_id) do
    HuddlAttendee
    |> Ash.Query.filter(user_id == ^reported_id and exists(huddl.attendees, user_id == ^actor_id))
    |> Ash.exists?(authorize?: false)
  end

  defp organizes_attended_huddl?(actor_id, reported_id) do
    Huddl
    |> Ash.Query.for_read(:read_for_group_lifecycle)
    |> Ash.Query.filter(creator_id == ^reported_id and exists(attendees, user_id == ^actor_id))
    |> Ash.exists?(authorize?: false)
  end

  defp organizes_public_huddl?(reported_id) do
    Huddl
    |> Ash.Query.for_read(:read, %{}, actor: nil)
    |> Ash.Query.filter(creator_id == ^reported_id)
    |> Ash.exists?()
  end
end
