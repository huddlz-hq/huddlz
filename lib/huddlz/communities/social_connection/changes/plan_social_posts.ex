defmodule Huddlz.Communities.SocialConnection.Changes.PlanSocialPosts do
  @moduledoc """
  Plans the connection's posts for the group's upcoming huddlz whenever
  its social schedule is set or it starts posting again. Moments that have
  already passed are skipped, and posts missed while it was paused or
  broken are dropped when it starts posting again, so nothing is sent late.
  """

  use Ash.Resource.Change

  alias Huddlz.Social.Schedule

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, connection ->
      if changeset.action.name in [:resume, :reconnect],
        do: :ok = Schedule.skip_missed(connection)

      :ok = Schedule.plan_connection(connection)
      {:ok, connection}
    end)
  end

  # Planning happens after the update commits, so an atomic update keeps it.
  @impl true
  def atomic(changeset, opts, context), do: {:ok, change(changeset, opts, context)}
end
