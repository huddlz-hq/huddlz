defmodule Huddlz.Communities.Huddl.Changes.PlanSocialPosts do
  @moduledoc """
  Keeps a huddl's social posts in step with it once the action commits:
  planned on each connection's social schedule while it can be posted,
  moved with its start, and dropped once it cannot (see
  `Huddlz.Social.Schedule`). A huddl that has just gone public is also
  announced to the connections that post when a huddl is published.
  """

  use Ash.Resource.Change

  alias Huddlz.Social.Schedule

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, huddl ->
      :ok = Schedule.plan_huddl(huddl)
      :ok = announce(changeset, huddl)
      {:ok, huddl}
    end)
  end

  defp announce(changeset, huddl) do
    if published_now?(changeset, huddl) and is_nil(huddl.huddl_template_id) do
      Schedule.announce(huddl)
    else
      :ok
    end
  end

  defp published_now?(%{action_type: :create}, huddl), do: huddl.lifecycle_state == :published

  defp published_now?(changeset, _huddl),
    do: changeset.context[:lifecycle_transition] == :published
end
