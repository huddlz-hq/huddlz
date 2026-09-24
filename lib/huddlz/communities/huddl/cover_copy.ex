defmodule Huddlz.Communities.Huddl.CoverCopy do
  @moduledoc """
  Gives one huddl a copy of another huddl's current cover image.

  The stored files are duplicated so each huddl owns its own cover: removing
  or cleaning up one huddl's image never touches the other's files.
  """

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlCoverImage
  alias Huddlz.Storage.HuddlCoverImages

  @doc """
  Copies `source_id`'s current cover onto `huddl_id`. A source without a
  cover copies nothing. `opts` are the options for creating the cover record.
  """
  def copy_current(source_id, huddl_id, opts) do
    case Communities.list_huddl_cover_images(source_id, authorize?: false) do
      {:ok, []} -> :ok
      {:ok, [image | _older]} -> copy_image(image, huddl_id, opts)
      {:error, error} -> {:error, error}
    end
  end

  defp copy_image(image, huddl_id, opts) do
    with {:ok, attrs} <- HuddlCoverImages.duplicate(image, huddl_id) do
      HuddlCoverImage
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :huddl_id, huddl_id), opts)
      |> Ash.create(authorize?: false)
      |> case do
        {:ok, _image} ->
          :ok

        {:error, error} ->
          HuddlCoverImages.delete(attrs.storage_path)
          HuddlCoverImages.delete(attrs.thumbnail_path)
          {:error, error}
      end
    end
  end
end
