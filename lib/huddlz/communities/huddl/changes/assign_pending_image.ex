defmodule Huddlz.Communities.Huddl.Changes.AssignPendingImage do
  @moduledoc """
  Assigns an eagerly uploaded pending image inside the huddl create transaction.

  Recurring-series generation is enqueued by a later after-action hook, so this
  guarantees the worker can observe and copy the source huddl's cover image.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlImage

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &assign_pending_image/2)
  end

  defp assign_pending_image(changeset, huddl) do
    case Ash.Changeset.get_argument(changeset, :pending_image_id) do
      nil ->
        {:ok, huddl}

      image_id ->
        with {:ok, %HuddlImage{} = image} <-
               Communities.get_huddl_image_by_id(image_id, authorize?: false),
             {:ok, _image} <-
               Communities.assign_huddl_image_to_huddl(
                 image,
                 huddl.id,
                 authorize?: false
               ) do
          {:ok, huddl}
        else
          {:ok, nil} ->
            {:error, ArgumentError.exception("pending huddl image not found")}

          {:error, error} ->
            {:error, error}
        end
    end
  end
end
