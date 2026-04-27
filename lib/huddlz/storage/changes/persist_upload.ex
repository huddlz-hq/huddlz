defmodule Huddlz.Storage.Changes.PersistUpload do
  @moduledoc """
  Resource change that runs an uploaded file through a storage pipeline
  module and writes the resulting paths/metadata onto the changeset.

  Options:

    * `:storage_module` (required) — module implementing
      `store(source_path, original_filename, content_type, parent_id)` and
      returning `{:ok, %{storage_path:, thumbnail_path:, size_bytes:}}`.
    * `:parent_arg` (required) — name of the action argument that holds
      the owning record's id (e.g. `:huddl_id`).
    * `:file_arg` (default `:file`) — name of the Ash.Type.File argument.

  The change extracts the upload, calls the storage module, and forces
  `:filename`, `:content_type`, `:size_bytes`, `:storage_path`, and
  `:thumbnail_path` onto the changeset before the action runs.
  """

  use Ash.Resource.Change

  alias Ash.Resource.Info

  @impl true
  def change(changeset, opts, _context) do
    storage_module = Keyword.fetch!(opts, :storage_module)
    parent_arg = Keyword.fetch!(opts, :parent_arg)
    file_arg = Keyword.get(opts, :file_arg, :file)

    Ash.Changeset.before_action(changeset, fn cs ->
      upload = Ash.Changeset.get_argument(cs, file_arg)
      parent_id = resolve_parent_id(cs, parent_arg)

      if is_nil(parent_id) do
        Ash.Changeset.add_error(cs, message: "is required", field: parent_arg)
      else
        do_persist(cs, upload, parent_id, storage_module, file_arg)
      end
    end)
  end

  # The owner id can come from an action argument, an explicit attribute
  # change, or — when `relate_actor`/`manage_relationship` is in play — a
  # queued relationship whose source attribute matches `parent_arg`. The
  # last one isn't reflected in `get_attribute` until the action commits,
  # so we peek at the queued related record.
  defp resolve_parent_id(changeset, parent_arg) do
    Ash.Changeset.get_argument(changeset, parent_arg) ||
      Ash.Changeset.get_attribute(changeset, parent_arg) ||
      parent_id_from_relationship(changeset, parent_arg)
  end

  defp parent_id_from_relationship(changeset, parent_arg) do
    with %{} = relationship <-
           Info.relationships(changeset.resource)
           |> Enum.find(&(&1.type == :belongs_to and &1.source_attribute == parent_arg)),
         [{[record | _], _opts} | _] <-
           Map.get(changeset.relationships || %{}, relationship.name) do
      Map.get(record, relationship.destination_attribute)
    else
      _ -> nil
    end
  end

  defp do_persist(changeset, upload, parent_id, storage_module, file_arg) do
    case extract_upload(upload) do
      {:ok, %{path: path, filename: filename, content_type: content_type}} ->
        case storage_module.store(path, filename, content_type, parent_id) do
          {:ok, metadata} ->
            changeset
            |> Ash.Changeset.force_change_attribute(:filename, filename)
            |> Ash.Changeset.force_change_attribute(:content_type, content_type)
            |> Ash.Changeset.force_change_attribute(:size_bytes, metadata.size_bytes)
            |> Ash.Changeset.force_change_attribute(:storage_path, metadata.storage_path)
            |> Ash.Changeset.force_change_attribute(:thumbnail_path, metadata.thumbnail_path)

          {:error, reason} ->
            Ash.Changeset.add_error(changeset, message: format_error(reason), field: file_arg)
        end

      {:error, reason} ->
        Ash.Changeset.add_error(changeset, message: format_error(reason), field: file_arg)
    end
  end

  defp extract_upload(%Plug.Upload{path: path, filename: filename, content_type: content_type}),
    do: {:ok, %{path: path, filename: filename, content_type: content_type}}

  defp extract_upload(%Ash.Type.File{} = file) do
    with {:ok, path} <- Ash.Type.File.path(file),
         {:ok, filename} <- Ash.Type.File.filename(file),
         {:ok, content_type} <- Ash.Type.File.content_type(file) do
      {:ok, %{path: path, filename: filename, content_type: content_type}}
    end
  end

  defp extract_upload(_), do: {:error, "expected a file upload"}

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(:invalid_extension), do: "Invalid file type. Allowed: JPG, PNG, WebP"
  defp format_error(:enoent), do: "Uploaded file is missing or unreadable"
  defp format_error({:image_processing_failed, _}), do: "Could not process image"
  defp format_error({:request_failed, _}), do: "Upload failed; please try again"
  defp format_error(reason), do: inspect(reason)
end
