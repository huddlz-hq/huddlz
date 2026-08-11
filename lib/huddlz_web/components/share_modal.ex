defmodule HuddlzWeb.Components.ShareModal do
  @moduledoc """
  Share options for a page's sidebar: a direct `mailto:` email action and a
  "QR code" action that opens a modal with a server-rendered QR SVG and a
  copyable link. Opening/closing the QR modal is handled entirely
  client-side via `HuddlzWeb.Components.Modal`'s JS commands — no
  `handle_event`, no server-side assign for open/closed state.
  """
  use Phoenix.Component

  alias HuddlzWeb.Components.Button
  alias HuddlzWeb.Components.Icon
  alias HuddlzWeb.Components.Input
  alias HuddlzWeb.Components.Modal

  attr :id, :string, required: true, doc: "id of the .share_modal the QR code option opens"
  attr :url, :string, required: true
  attr :title, :string, required: true

  def share_actions(assigns) do
    ~H"""
    <div class="side-actions">
      <Button.button variant={:secondary} href={mailto_href(@url, @title)}>
        <Icon.icon name="hero-envelope" class="size-4" /> Email
      </Button.button>
      <Button.button
        id={"#{@id}-open"}
        type="button"
        variant={:secondary}
        phx-click={Modal.show_modal(@id)}
      >
        <Icon.icon name="hero-qr-code" class="size-4" /> QR code
      </Button.button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :url, :string, required: true
  attr :label, :string, default: "page"

  def share_modal(assigns) do
    assigns = assign(assigns, :qr_svg, qr_svg(assigns.url))

    ~H"""
    <Modal.modal id={@id}>
      <div class="share-modal-copy">
        <span class="eyebrow">QR code</span>
        <h2 id={"#{@id}-title"}>Scan to open this {@label}</h2>
      </div>

      <div class="share-modal-qr">
        <div class="qr-frame">
          {Phoenix.HTML.raw(@qr_svg)}
        </div>
      </div>

      <div class="share-modal-link">
        <Input.input
          id={"#{@id}-url"}
          name="share-url"
          type="text"
          label="Link"
          value={@url}
          readonly
        />
        <button
          type="button"
          id={"#{@id}-copy"}
          phx-hook="ClipboardCopy"
          data-value={@url}
          class="btn-secondary"
        >
          <span data-copy-label>Copy link</span>
        </button>
      </div>
    </Modal.modal>
    """
  end

  defp qr_svg(url) do
    url
    |> EQRCode.encode()
    |> EQRCode.svg(width: 220, color: "#000", background_color: "#FFF")
    |> String.replace(~r/^<\?xml[^>]*\?>/, "")
  end

  defp mailto_href(url, title) do
    "mailto:?subject=" <> mailto_encode(title) <> "&body=" <> mailto_encode(url)
  end

  defp mailto_encode(string) do
    string
    |> to_string()
    |> URI.encode_www_form()
    |> String.replace("+", "%20")
  end
end
