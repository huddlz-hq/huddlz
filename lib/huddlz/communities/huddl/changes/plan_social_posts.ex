defmodule Huddlz.Communities.Huddl.Changes.PlanSocialPosts do
  @moduledoc """
  Keeps a huddl's social posts in step with it once the action commits:
  planned on each connection's social schedule while it can be posted,
  moved with its start, and dropped once it cannot (see
  `Huddlz.Social.Schedule`). A huddl that has just gone public is also
  announced to the connections that post when a huddl is published; a new
  series is announced once, by its first huddl, rather than date by date.
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
    cond do
      not published_now?(changeset, huddl) ->
        :ok

      Ash.Changeset.get_argument(changeset, :is_recurring) == true ->
        Schedule.announce(huddl, :series)

      is_nil(huddl.huddl_template_id) ->
        Schedule.announce(huddl, :when_published)

      true ->
        :ok
    end
  end

  defp published_now?(%{action_type: :create}, huddl), do: huddl.lifecycle_state == :published

  defp published_now?(changeset, _huddl),
    do: changeset.context[:lifecycle_transition] == :published
end
