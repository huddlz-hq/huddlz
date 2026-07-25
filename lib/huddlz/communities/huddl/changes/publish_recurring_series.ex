defmodule Huddlz.Communities.Huddl.Changes.PublishRecurringSeries do
  @moduledoc """
  Publishes already-generated future instances with their series source.

  Only the source transition notifies group members, so a recurring series is
  announced once rather than once per occurrence.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &publish_future_instances/2)
  end

  defp publish_future_instances(changeset, huddl) do
    if publish_series?(changeset, huddl) do
      huddl
      |> future_drafts()
      |> Enum.each(&publish_without_fanout!/1)
    end

    {:ok, huddl}
  end

  defp publish_series?(changeset, huddl) do
    changeset.context[:lifecycle_transition] == :published and
      Ash.Changeset.get_argument(changeset, :publish_series?) != false and
      not is_nil(huddl.huddl_template_id)
  end

  defp future_drafts(huddl) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: huddl.huddl_template_id,
      starting_after: huddl.starts_at
    })
    |> Ash.Query.filter(lifecycle_state == :draft)
    |> Ash.read!(authorize?: false)
  end

  defp publish_without_fanout!(huddl) do
    huddl
    |> Ash.Changeset.for_update(:publish, %{
      publish_series?: false,
      notify_members?: false
    })
    |> Ash.update!(authorize?: false)
  end
end
