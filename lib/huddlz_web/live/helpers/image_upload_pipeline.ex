defmodule HuddlzWeb.Live.Helpers.ImageUploadPipeline do
  @moduledoc """
  Shared eager-upload pipeline used by the huddl and group new/edit
  LiveViews. A chosen file is uploaded at once and prepared as a pending
  cover before the form is saved:

    1. When the bytes have arrived (`start_eager_upload/2`), the file is
       copied aside and the entry is kept, so the browser's own preview
       stays in the slot, and the cover is prepared off the LiveView
       process with `start_async/3`, so the form stays usable.
    2. When that finishes (`finish_eager_upload/3`, from `handle_async/3`),
       the entry is dropped and the pending image id and preview URL are
       assigned, or the error is.
    3. On re-upload or cancel, the previous pending image is soft-deleted.

  Call sites pass a config map:

      %{
        upload_name: :group_image | :huddl_cover_image,
        storage: Huddlz.Storage.GroupImages,   # needs store_pending/3, url/1 and delete/1
        create_pending: fn actor, entry, metadata -> {:ok, image} | {:error, reason} end,
        cleanup: fn socket, image_id -> :ok end
      }

  The storage module can be swapped per module through the
  `:image_storage_overrides` application env (a map from module to
  module), which the browser suite uses to slow preparation down.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [cancel_upload: 3, consume_uploaded_entries: 3, start_async: 3]
  import HuddlzWeb.Live.Helpers.UploadHelpers, only: [format_upload_error: 1]

  require Logger

  @async_name :prepare_cover

  @doc "The `handle_async/3` name the pipeline reports back under."
  def async_name, do: @async_name

  @doc """
  Copy the finished upload aside, keep its entry for the preview, and
  prepare the cover off the LiveView process.
  """
  def start_eager_upload(socket, %{} = config) do
    socket = cleanup_pending_image(socket, config)
    actor = socket.assigns.current_user
    storage = storage(config)

    copies =
      consume_uploaded_entries(socket, config.upload_name, fn %{path: path}, entry ->
        copy =
          Path.join(System.tmp_dir!(), "cover-#{entry.uuid}#{Path.extname(entry.client_name)}")

        File.cp!(path, copy)
        {:postpone, {copy, entry}}
      end)

    case copies do
      [{copy, entry}] ->
        socket
        |> assign(:upload_processing, true)
        |> assign(:image_error, nil)
        |> start_async(@async_name, fn ->
          prepare(copy, entry, actor, storage, config)
        end)

      [] ->
        socket
    end
  end

  @doc "Apply the prepared cover, or the error, and drop the kept entry."
  def finish_eager_upload(socket, result, %{} = config) do
    consume_uploaded_entries(socket, config.upload_name, fn _meta, _entry -> {:ok, :done} end)

    socket = assign(socket, :upload_processing, false)

    case result do
      {:ok, {:success, image_id, thumbnail_path}} ->
        socket
        |> assign(:pending_image_id, image_id)
        |> assign(:pending_preview_url, storage(config).url(thumbnail_path))
        |> assign(:image_error, nil)

      {:ok, {:error, reason}} ->
        assign(socket, :image_error, format_upload_error(reason))

      {:exit, _reason} ->
        assign(socket, :image_error, format_upload_error(:failed))
    end
  end

  @doc """
  Cancel entries the browser rules refused, so the slot can take another
  file. Called from the form's validate event.
  """
  def drop_invalid_entries(socket, %{upload_name: name}) do
    upload = socket.assigns.uploads[name]

    Enum.reduce(upload.entries, socket, fn entry, socket ->
      if entry.valid?, do: socket, else: cancel_upload(socket, name, entry.ref)
    end)
  end

  @doc "Submit an edit with the pending cover selected by this LiveView."
  def submit_edit(%{assigns: %{image_error: message}}, _params) when is_binary(message),
    do: {:upload_error, message}

  def submit_edit(socket, params) do
    submit_with_cover(socket, params)
  end

  @doc "Pass the server-selected cover to the parent save transaction."
  def submit_with_cover(%{assigns: %{upload_processing: true}}, _params),
    do: {:upload_error, "Wait for the cover to finish uploading."}

  def submit_with_cover(socket, params) do
    pending_image_id = socket.assigns.pending_image_id

    socket.assigns.form.source
    |> AshPhoenix.Form.update_options(
      &Keyword.put(&1, :private_arguments, %{pending_image_id: pending_image_id})
    )
    |> AshPhoenix.Form.submit(params: params)
  end

  @doc "Refresh the saved cover after a failed submit while retaining the edit form."
  def refresh_saved_cover(socket, parent, loads) do
    case Ash.load(socket.assigns[parent], loads, actor: socket.assigns.current_user) do
      # The open huddl form still needs its group if it was archived during the edit.
      {:ok, %{group: nil}} -> socket
      {:ok, refreshed} -> assign(socket, parent, refreshed)
      {:error, _} -> socket
    end
  end

  @doc "Return the cover-specific error and the message for a failed form submission."
  def save_errors(form) do
    errors = AshPhoenix.Form.errors(form, format: :simple)
    cover_error = errors[:pending_image_id]

    case errors do
      [] ->
        {nil, "Changes could not be saved."}

      _ ->
        {cover_error,
         cover_error || Enum.join(AshPhoenix.Form.errors(form, format: :plaintext), ". ")}
    end
  end

  @doc "Show the published cover when a form error leaves a replacement pending for retry."
  def edit_cover_error(nil, %{source: %{just_submitted?: true}}, pending_id)
      when not is_nil(pending_id),
      do: "The replacement is still pending. Correct the form and save again."

  def edit_cover_error(image_error, _form, _pending_id), do: image_error

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

  @doc "The storage module for a config, honouring `:image_storage_overrides`."
  def storage(%{storage: storage}) do
    :huddlz
    |> Application.get_env(:image_storage_overrides, %{})
    |> Map.get(storage, storage)
  end

  defp prepare(copy, entry, actor, storage, config) do
    with {:ok, metadata} <- storage.store_pending(copy, entry.client_name, entry.client_type) do
      persist_pending(metadata, actor, entry, config.create_pending, storage)
    end
  after
    File.rm(copy)
  end

  defp persist_pending(metadata, actor, entry, create_pending, storage) do
    case create_pending.(actor, entry, metadata) do
      {:ok, image} ->
        {:success, image.id, metadata.thumbnail_path}

      {:error, reason} ->
        delete_stored_cover(storage, metadata)
        {:error, reason}
    end
  rescue
    error ->
      delete_stored_cover(storage, metadata)
      reraise error, __STACKTRACE__
  end

  defp delete_stored_cover(storage, metadata) do
    Enum.each([metadata.storage_path, metadata.thumbnail_path], fn path ->
      case storage.delete(path) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to delete unpublished cover #{path}: #{inspect(reason)}")
      end
    end)
  end
end
