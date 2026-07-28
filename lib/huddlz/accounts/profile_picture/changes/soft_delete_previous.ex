defmodule Huddlz.Accounts.ProfilePicture.Changes.SoftDeletePrevious do
  @moduledoc """
  Retires a user's previous profile pictures after a replacement is created.

  The after-action hook runs inside the replacement transaction, so any
  failure rolls back both the new record and the previous-picture updates.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, new_picture ->
      actor = changeset.context[:private][:actor]

      with {:ok, pictures} <-
             Accounts.list_profile_pictures(new_picture.user_id, actor: actor),
           :ok <- soft_delete_previous(pictures, new_picture.id, actor) do
        {:ok, new_picture}
      end
    end)
  end

  defp soft_delete_previous(pictures, current_picture_id, actor) do
    pictures
    |> Enum.reject(&(&1.id == current_picture_id))
    |> Enum.reduce_while(:ok, fn picture, :ok ->
      case Accounts.soft_delete_profile_picture(picture, actor: actor) do
        {:ok, _picture} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
