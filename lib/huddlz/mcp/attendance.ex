defmodule Huddlz.Mcp.Attendance do
  alias Ash.Error.Changes.InvalidArgument
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Huddlz.Communities
  alias Huddlz.Mcp.HuddlResult

  @impl true
  def run(%{action: %{name: :get_huddl}, arguments: args}, _opts, context) do
    with {:ok, huddl} <-
           Communities.get_huddl(args.huddl_id,
             scope: context,
             load: HuddlResult.load()
           ) do
      {:ok, HuddlResult.from_record(huddl)}
    end
  end

  def run(%{action: %{name: action}, arguments: %{confirmed: true} = args}, _opts, context) do
    with {:ok, huddl} <- Communities.get_huddl(args.huddl_id, scope: context),
         {:ok, updated} <- change_attendance(action, huddl, context),
         {:ok, loaded} <- Ash.load(updated, HuddlResult.load(), scope: context) do
      {:ok, HuddlResult.from_record(loaded)}
    end
  end

  def run(_input, _opts, _context),
    do:
      {:error,
       InvalidArgument.exception(
         field: :confirmed,
         message:
           "Obtain the person's explicit intent for this huddl before setting confirmed to true."
       )}

  defp change_attendance(:rsvp_huddl, huddl, context),
    do: Communities.rsvp_huddl(huddl, %{}, scope: context)

  defp change_attendance(:cancel_rsvp, huddl, context),
    do: Communities.cancel_rsvp_huddl(huddl, %{}, scope: context)

  defp change_attendance(:join_waitlist, huddl, context),
    do: Communities.join_waitlist_huddl(huddl, %{}, scope: context)
end
