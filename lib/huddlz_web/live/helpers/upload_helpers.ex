defmodule HuddlzWeb.Live.Helpers.UploadHelpers do
  @moduledoc """
  Shared upload helper functions for LiveViews that handle image uploads.
  """

  @doc """
  Standard single-image upload config (JPG/PNG/WebP, 5MB max, auto-upload).
  """
  def allow_image_upload(socket, name, progress_handler) do
    Phoenix.LiveView.allow_upload(socket, name,
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: 1,
      max_file_size: 5_000_000,
      auto_upload: true,
      progress: progress_handler
    )
  end

  @doc """
  Converts a LiveView upload error atom to a user-friendly string.
  """
  def upload_error_to_string(:too_large), do: "File is too large (max 5MB)"

  def upload_error_to_string(:not_accepted),
    do: "Invalid file type. Please use JPG, PNG, or WebP"

  def upload_error_to_string(:too_many_files), do: "Only one file can be uploaded at a time"
  def upload_error_to_string(err), do: "Upload error: #{inspect(err)}"

  @doc """
  Formats an upload error reason into a user-friendly message.
  """
  def format_upload_error(:invalid_extension),
    do: "Invalid file type. Please use JPG, PNG, or WebP"

  def format_upload_error(msg) when is_binary(msg), do: msg
  def format_upload_error(_), do: "Upload failed"
end
