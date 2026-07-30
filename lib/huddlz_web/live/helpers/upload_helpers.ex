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
  def upload_error_to_string(:too_large), do: "Image must be 5 MB or smaller."

  def upload_error_to_string(:not_accepted),
    do: "Choose a JPG, PNG, or WebP image."

  def upload_error_to_string(:too_many_files), do: "Choose one image at a time."
  def upload_error_to_string(err), do: "Upload error: #{inspect(err)}"

  @doc """
  Formats an upload error reason into a user-friendly message.
  """
  def format_upload_error(:invalid_extension),
    do: "Choose a JPG, PNG, or WebP image."

  def format_upload_error(:invalid_image),
    do: "That file could not be read as an image. Choose another JPG, PNG, or WebP image."

  def format_upload_error(msg) when is_binary(msg), do: msg
  def format_upload_error(_), do: "The image could not be uploaded. Please try again."
end
