defmodule Huddlz.Communities.SocialConnection.Validations.GroupIsPublic do
  @moduledoc """
  Only a public, open group connects a place: posts carry links that would
  dead-end for anyone outside a private group, and an archived group has
  nothing to post.
  """

  use Ash.Resource.Validation

  alias Huddlz.Communities.Group

  @impl true
  def validate(changeset, _opts, _context) do
    group_id = Ash.Changeset.get_argument(changeset, :group_id)

    case Ash.get(Group, group_id, authorize?: false) do
      {:ok, %Group{is_public: true, archived_at: nil}} ->
        :ok

      {:ok, _group} ->
        {:error, field: :group_id, message: "only public groups post to outside places"}

      {:error, _} ->
        {:error, field: :group_id, message: "group not found"}
    end
  end
end
