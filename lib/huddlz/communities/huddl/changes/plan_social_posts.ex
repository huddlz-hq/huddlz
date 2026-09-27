defmodule Huddlz.Communities.Huddl.Changes.PlanSocialPosts do
  @moduledoc """
  Keeps a huddl's social posts in step with it once the action commits:
  planned on each connection's social schedule while it can be posted,
  moved with its start, and dropped once it cannot (see
  `Huddlz.Social.Schedule`).
  """

  use Ash.Resource.Change

  alias Huddlz.Social.Schedule

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, huddl ->
      :ok = Schedule.plan_huddl(huddl)
      {:ok, huddl}
    end)
  end
end
