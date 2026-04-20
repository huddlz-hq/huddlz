defmodule HuddlzWeb.Live.Helpers.ImageUploadPipeline do
  @moduledoc """
  Shared eager-upload pipeline used by the huddl and group new/edit
  LiveViews. Handles the flow:

    1. Consume a just-completed LiveView upload entry
    2. Copy the file into pending storage
    3. Create a pending Ash image record
    4. Assign preview URL / image id to the socket
    5. On re-upload or cancel, soft-delete the previous pending image

  Call sites pass a config map:

      %{
        upload_name: :group_image | :huddl_image,
        storage: Huddlz.Storage.GroupImages,   # needs store_pending/3 + url/1
        create_pending: fn socket, entry, metadata -> {:ok, image} | {:error, reason} end,
        cleanup: fn socket, image_id -> :ok end
      }
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [consume_uploaded_entries: 3]
  import HuddlzWeb.Live.Helpers.UploadHelpers, only: [format_upload_error: 1]

  @doc "Run the eager-upload pipeline and return the updated socket."
  def process_eager_upload(socket, %{} = config) do
    socket = cleanup_pending_image(socket, config)
    socket = assign(socket, :upload_processing, true)

    result =
      consume_uploaded_entries(socket, config.upload_name, fn %{path: path}, entry ->
        store_and_create_pending_image(path, entry, socket, config)
      end)

    socket
    |> assign(:upload_processing, false)
    |> apply_upload_result(result, config)
  end

  @doc "Soft-delete any pending image attached to the socket and clear the preview assigns."
  def cleanup_pending_image(socket, %{cleanup: cleanup}) do
    case socket.assigns[:pending_image_id] do
      nil ->
        socket

      image_id ->
        cleanup.(socket, image_id)
        assign(socket, pending_image_id: nil, pending_preview_url: nil)
    end
  end

  defp store_and_create_pending_image(path, entry, socket, config) do
    with {:ok, metadata} <-
           config.storage.store_pending(path, entry.client_name, entry.client_type),
         {:ok, image} <- config.create_pending.(socket, entry, metadata) do
      {:ok, {:success, image.id, metadata.thumbnail_path}}
    else
      {:error, reason} -> {:ok, {:error, reason}}
    end
  end

  defp apply_upload_result(socket, result, config) do
    case result do
      [{:success, image_id, thumbnail_path}] ->
        socket
        |> assign(:pending_image_id, image_id)
        |> assign(:pending_preview_url, config.storage.url(thumbnail_path))
        |> assign(:image_error, nil)

      [{:error, reason}] ->
        assign(socket, :image_error, format_upload_error(reason))

      [] ->
        socket
    end
  end
end
