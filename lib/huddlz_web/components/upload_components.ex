defmodule HuddlzWeb.Components.UploadComponents do
  @moduledoc """
  Shared cover-image upload panel used by the huddl create and edit forms.

  ```
  <.cover_image_panel upload={@uploads.huddl_image} image_error={@image_error}>
    <:preview>...</:preview>
  </.cover_image_panel>
  ```
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Button, only: [button: 1]
  import HuddlzWeb.Live.Helpers.UploadHelpers, only: [upload_error_to_string: 1]

  attr :upload, :any, required: true
  attr :image_error, :string, default: nil
  attr :optional, :boolean, default: false

  slot :preview do
    attr :hide_upload_zone, :boolean
  end

  def cover_image_panel(assigns) do
    assigns = assign(assigns, :show_upload_zone, show_upload_zone?(assigns.preview))

    ~H"""
    <div class="panel">
      <div class="panel-head">
        <h2>Cover image</h2>
      </div>

      <label for={@upload.ref} class="sr-only">Cover image</label>
      <.live_file_input upload={@upload} class="hidden" />

      {render_slot(@preview)}

      <div :if={@show_upload_zone} class="upload-zone" phx-drop-target={@upload.ref}>
        <div class="upload-icon">
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.6"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <rect x="3" y="3" width="18" height="18" rx="2" /><circle cx="9" cy="9" r="2" /><path d="m21 15-5-5L5 21" />
          </svg>
        </div>
        <label for={@upload.ref} class="upload-prompt">
          Drop a 16:9 image, or <span class="upload-link">browse</span>
        </label>
        <div class="upload-meta muted">
          JPG, PNG, WebP · 5 MB max{if @optional, do: " · optional", else: ""}
        </div>
      </div>

      <%= for entry <- @upload.entries do %>
        <div class="image-preview image-preview-progress">
          <div class="card-cover">
            <.live_img_preview entry={entry} class="card-cover-img" />
          </div>
          <div class="image-preview-foot">
            <span>{entry.client_name} · {entry.progress}%</span>
            <.button
              variant={:muted}
              type="button"
              phx-click="cancel_image_upload"
              phx-value-ref={entry.ref}
            >
              Cancel
            </.button>
          </div>
        </div>
        <p :for={err <- upload_errors(@upload, entry)} class="form-error">
          {upload_error_to_string(err)}
        </p>
      <% end %>

      <p :if={@image_error} class="form-error">{@image_error}</p>
      <p :for={err <- upload_errors(@upload)} class="form-error">
        {upload_error_to_string(err)}
      </p>
    </div>
    """
  end

  defp show_upload_zone?(preview) do
    Enum.all?(preview, &(not Map.get(&1, :hide_upload_zone, false)))
  end
end
