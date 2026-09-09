defmodule HuddlzWeb.Components.UploadComponents do
  @moduledoc """
  The cover slot: one 16:9 field for a group or huddl cover that never
  changes size while a picture is chosen, uploaded, prepared, shown or
  refused. Used by the group and huddl create and edit forms.

  Choosing a picture opens the crop sheet (`crop_sheet/1`, driven by the
  `CoverCrop` hook in `assets/js/cover_crop.mjs`) before anything uploads;
  Use photo hands the 16:9 crop to the `live_file_input` as a JPEG, so the
  server pipeline sees an ordinary upload.

  ```
  <.cover_upload
    id="group-cover-upload"
    upload={@uploads.group_image}
    image_url={@pending_preview_url}
    caption="Image uploaded · ready to publish."
    processing?={@upload_processing}
    image_error={@image_error}
  >
    <:actions>
      <.button variant={:muted} type="button" phx-click="cancel_pending_image">Remove</.button>
    </:actions>
  </.cover_upload>
  ```

  States, in the order they are checked:

    * uploading: a file is on its way, or has arrived and the server is
      preparing the 16:9 cover. The browser's own preview of the file
      fills the slot with the progress over its bottom edge.
    * error: the file was refused, by the browser rules or by the server.
      The message lives in the slot with a way to choose another file.
    * uploaded: `image_url` is set. The cover as the card and page will
      show it, with Replace and the caller's actions over the corner.
    * idle: the dashed prompt.
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Button, only: [button: 1]
  import HuddlzWeb.Components.Icon, only: [icon: 1]
  import HuddlzWeb.Live.Helpers.UploadHelpers, only: [upload_error_to_string: 1]

  attr :id, :string, required: true
  attr :upload, :any, required: true, doc: "the `@uploads` config"
  attr :image_url, :string, default: nil, doc: "the cover to show, pending or current"
  attr :caption, :string, default: nil, doc: "one line under an uploaded cover"
  attr :processing?, :boolean, default: false, doc: "the server is preparing the cover"
  attr :image_error, :string, default: nil, doc: "why the server refused the file"
  attr :optional, :boolean, default: false

  slot :actions, doc: "controls over the corner of an uploaded cover, after Replace"

  def cover_upload(assigns) do
    entry = List.first(assigns.upload.entries)
    errors = slot_errors(assigns.upload, entry, assigns.image_error)
    state = slot_state(entry, errors, assigns.image_url)

    assigns =
      assigns
      |> assign(:entry, entry)
      |> assign(:errors, errors)
      |> assign(:state, state)

    ~H"""
    <div
      id={@id}
      class="cover-upload"
      data-state={@state}
      phx-hook="CoverCrop"
      data-upload-name={@upload.name}
      data-shape="wide"
      data-output-width="1920"
    >
      <label for={@upload.ref} class="sr-only">Cover image</label>
      <.live_file_input upload={@upload} class="hidden" />

      <div class="cover-slot" data-crop-drop>
        <%= case @state do %>
          <% :uploading -> %>
            <.live_img_preview entry={@entry} class="cover-slot-img" />
            <div class="cover-slot-bar" role="status" aria-live="polite">
              <div class="cover-slot-bar-row">
                <%= if @entry.done? do %>
                  <span class="cover-slot-file">
                    <span class="cover-slot-spinner" aria-hidden="true"></span> Preparing the cover…
                  </span>
                  <span class="cover-slot-pct">{@entry.client_name}</span>
                <% else %>
                  <span class="cover-slot-file">
                    {@entry.client_name} · {format_size(@entry.client_size)}
                  </span>
                  <span class="cover-slot-pct">{@entry.progress}%</span>
                  <button
                    type="button"
                    class="cover-slot-cancel"
                    phx-click="cancel_image_upload"
                    phx-value-ref={@entry.ref}
                  >
                    Cancel
                  </button>
                <% end %>
              </div>
              <div class={["cover-slot-track", @entry.done? && "is-busy"]} aria-hidden="true">
                <span style={"width: #{if @entry.done?, do: 40, else: @entry.progress}%"}></span>
              </div>
            </div>
          <% :error -> %>
            <span class="cover-slot-icon is-error" aria-hidden="true">
              <.icon name="hero-x-circle" class="size-5" />
            </span>
            <p :for={message <- @errors} class="cover-slot-error">{message}</p>
            <label for={@upload.ref} class="cover-slot-hint">
              Choose another JPG, PNG or WebP · <span class="upload-link">browse</span>
            </label>
          <% :uploaded -> %>
            <img class="cover-slot-img" src={@image_url} alt="" />
            <div class="cover-slot-actions">
              <label for={@upload.ref} class="btn-secondary btn-sm cover-slot-replace">
                Replace
              </label>
              {render_slot(@actions)}
            </div>
          <% :idle -> %>
            <span class="cover-slot-icon" aria-hidden="true">
              <.icon name="hero-photo" class="size-5" />
            </span>
            <label for={@upload.ref} class="cover-slot-prompt">
              Drop a 16:9 image, or <span class="upload-link">browse</span>
            </label>
            <p class="cover-slot-meta">
              JPG, PNG, WebP · 5 MB max{if @optional, do: " · optional", else: ""}
            </p>
        <% end %>
      </div>

      <p :if={@state == :uploaded && @caption} class="cover-slot-caption">{@caption}</p>

      <.crop_sheet id={@id} title="Crop the cover" />
    </div>
    """
  end

  @doc """
  The crop sheet the `CoverCrop` hook opens when a picture is chosen: a
  native dialog with the picture in a 16:9 (or square) window, a zoom
  slider and Use photo. LiveView leaves its contents alone; the hook
  fills in the picture and does the geometry. Render it inside the hook
  element, which also holds the `live_file_input` the hook listens to.
  """
  attr :id, :string, required: true, doc: "the hook element's id; the dialog is `<id>-crop`"
  attr :title, :string, required: true
  attr :shape, :string, default: "wide", values: ~w(wide square)

  def crop_sheet(assigns) do
    ~H"""
    <dialog
      id={"#{@id}-crop"}
      class="crop-sheet"
      phx-update="ignore"
      aria-labelledby={"#{@id}-crop-title"}
    >
      <div class="crop-sheet-head">
        <h2 id={"#{@id}-crop-title"} class="crop-sheet-title">{@title}</h2>
      </div>
      <p class="crop-sheet-hint">Drag to move · pinch, scroll or slide to zoom</p>
      <button type="button" class="modal-close" data-crop-close aria-label="Cancel">
        <.icon name="hero-x-mark" class="size-5" />
      </button>
      <div
        class="crop-stage"
        data-crop-stage
        tabindex="0"
        role="img"
        aria-label="Your picture in the frame. Drag to move it; arrow keys nudge, plus and minus zoom."
      >
        <img class="crop-pic" alt="" draggable="false" />
        <div class="crop-window" data-shape={@shape} aria-hidden="true"></div>
      </div>
      <div class="crop-zoom">
        <.icon name="hero-magnifying-glass-minus" class="size-5" />
        <input
          type="range"
          min="1"
          max="3"
          step="0.01"
          value="1"
          aria-label="Zoom"
          data-crop-zoom
        />
        <.icon name="hero-magnifying-glass-plus" class="size-5" />
        <span class="crop-zoom-value" data-crop-zoom-value aria-hidden="true">1.0×</span>
        <.button variant={:muted} type="button" class="btn-sm" data-crop-reset hidden>
          Reset
        </.button>
      </div>
      <div class="crop-sheet-foot">
        <p class="crop-sheet-meta" data-crop-meta></p>
        <div class="crop-sheet-actions">
          <.button variant={:secondary} type="button" data-crop-cancel>Cancel</.button>
          <.button variant={:primary} type="button" data-crop-use autofocus>Use photo</.button>
        </div>
      </div>
    </dialog>
    """
  end

  @doc """
  A form panel headed "Cover image" around the slot, for the huddl forms.
  Takes the same attributes and slot as `cover_upload/1`.
  """
  attr :id, :string, required: true
  attr :upload, :any, required: true
  attr :image_url, :string, default: nil
  attr :caption, :string, default: nil
  attr :processing?, :boolean, default: false
  attr :image_error, :string, default: nil
  attr :optional, :boolean, default: false
  slot :actions

  def cover_image_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <h2>Cover image</h2>
      </div>
      <.cover_upload
        id={@id}
        upload={@upload}
        image_url={@image_url}
        caption={@caption}
        processing?={@processing?}
        image_error={@image_error}
        optional={@optional}
      >
        <:actions>{render_slot(@actions)}</:actions>
      </.cover_upload>
    </div>
    """
  end

  # A muted Remove-style control sized for the slot's corner.
  attr :rest, :global, include: ~w(phx-click phx-value-ref type id)
  slot :inner_block, required: true

  def cover_slot_button(assigns) do
    ~H"""
    <.button variant={:muted} class="btn-sm cover-slot-action" {@rest}>
      {render_slot(@inner_block)}
    </.button>
    """
  end

  defp slot_state(entry, errors, image_url) do
    cond do
      entry && errors == [] -> :uploading
      errors != [] -> :error
      image_url -> :uploaded
      true -> :idle
    end
  end

  defp slot_errors(upload, entry, image_error) do
    entry_errors = if entry, do: upload_errors(upload, entry), else: []

    (upload_errors(upload) ++ entry_errors)
    |> Enum.uniq()
    |> Enum.map(&upload_error_to_string/1)
    |> Kernel.++(List.wrap(image_error))
  end

  defp format_size(bytes) when is_integer(bytes) and bytes >= 1_000_000,
    do: "#{Float.round(bytes / 1_000_000, 1)} MB"

  defp format_size(bytes) when is_integer(bytes) and bytes >= 1_000,
    do: "#{div(bytes, 1_000)} KB"

  defp format_size(bytes) when is_integer(bytes), do: "#{bytes} B"
  defp format_size(_), do: ""
end
