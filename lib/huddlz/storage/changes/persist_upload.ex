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

  @impl true
  def change(changeset, opts, _context) do
    storage_module = Keyword.fetch!(opts, :storage_module)
    parent_arg = Keyword.fetch!(opts, :parent_arg)
    file_arg = Keyword.get(opts, :file_arg, :file)

    upload = Ash.Changeset.get_argument(changeset, file_arg)

    parent_id =
      Ash.Changeset.get_argument(changeset, parent_arg) ||
        Ash.Changeset.get_attribute(changeset, parent_arg)

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
  defp format_error(reason), do: inspect(reason)
end
