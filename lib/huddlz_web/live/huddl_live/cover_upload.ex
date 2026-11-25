defmodule HuddlzWeb.HuddlLive.CoverUpload do
  @moduledoc """
  Prepares a pending cover for the group that owns the huddl form.
  The form's create or update action attaches it when the organizer saves.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Huddlz.Communities
  alias Huddlz.Storage.HuddlCoverImages
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline
  alias HuddlzWeb.Live.Helpers.UploadHelpers

  @upload %{upload_name: :huddl_cover_image, storage: HuddlCoverImages}

  def init(socket) do
    assign(socket,
      image_error: nil,
      pending_image_id: nil,
      pending_preview_url: nil,
      upload_processing: false
    )
  end

  def allow(socket, group_id) do
    config =
      Map.merge(@upload, %{
        create_pending: &create_pending(group_id, &1, &2, &3),
        cleanup: &delete_pending/2
      })

    UploadHelpers.allow_image_upload(socket, @upload.upload_name, fn
      _name, %{done?: true}, socket ->
        {:noreply, ImageUploadPipeline.start_eager_upload(socket, config)}

      _name, _entry, socket ->
        {:noreply, socket}
    end)
  end

  def finish(socket, result), do: ImageUploadPipeline.finish_eager_upload(socket, result, @upload)
  def drop_invalid_entries(socket), do: ImageUploadPipeline.drop_invalid_entries(socket, @upload)

  def discard(socket),
    do: ImageUploadPipeline.cleanup_pending_image(socket, %{cleanup: &delete_pending/2})

  defp create_pending(group_id, actor, entry, metadata) do
    Communities.create_pending_huddl_cover_image(
      group_id,
      %{
        filename: entry.client_name,
        content_type: entry.client_type,
        size_bytes: metadata.size_bytes,
        storage_path: metadata.storage_path,
        thumbnail_path: metadata.thumbnail_path
      },
      actor: actor
    )
  end

  defp delete_pending(socket, image_id) do
    with {:ok, image} <- Communities.get_huddl_cover_image_by_id(image_id),
         true <- is_nil(image.huddl_id) do
      Communities.soft_delete_huddl_cover_image(image, actor: socket.assigns.current_user)
    end
  end
end
