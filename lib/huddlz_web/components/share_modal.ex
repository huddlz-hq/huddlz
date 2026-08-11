defmodule HuddlzWeb.Components.ShareModal do
  @moduledoc """
  Share button + modal: copy link, mailto email, and a server-rendered QR
  code pointing at the current page's canonical URL. Opening/closing is
  handled entirely client-side via `HuddlzWeb.Components.Modal`'s JS
  commands — no `handle_event`, no server-side assign for open/closed
  state.
  """
  use Phoenix.Component

  alias HuddlzWeb.Components.Button
  alias HuddlzWeb.Components.Icon
  alias HuddlzWeb.Components.Input
  alias HuddlzWeb.Components.Modal

  attr :id, :string, required: true, doc: "id of the .share_modal this button opens"
  attr :class, :any, default: nil

  def share_button(assigns) do
    ~H"""
    <button
      type="button"
      class={["share-trigger", @class]}
      phx-click={Modal.show_modal(@id)}
      aria-label="Share"
    >
      <Icon.icon name="hero-share" class="size-5" />
    </button>
    """
  end

  attr :id, :string, required: true
  attr :url, :string, required: true
  attr :title, :string, required: true
  attr :label, :string, default: "page"

  def share_modal(assigns) do
    assigns = assign(assigns, :qr_svg, qr_svg(assigns.url))

    ~H"""
    <Modal.modal id={@id}>
      <div class="share-modal-copy">
        <span class="eyebrow">Share</span>
        <h2 id={"#{@id}-title"}>Share this {@label}</h2>
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

      <div class="share-modal-actions">
        <Button.button variant={:secondary} href={mailto_href(@url, @title)}>
          Email
        </Button.button>
      </div>

      <div class="share-modal-qr">
        <div class="qr-frame">
          {Phoenix.HTML.raw(@qr_svg)}
        </div>
        <p class="muted">Scan to open this {@label} on a phone.</p>
      </div>
    </Modal.modal>
    """
  end

  defp qr_svg(url) do
    url
    |> EQRCode.encode()
    |> EQRCode.svg(width: 220, viewbox: true, color: "#000", background_color: "#FFF")
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
