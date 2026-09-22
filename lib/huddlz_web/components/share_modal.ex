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

  # Places with a public compose URL, in the order they are offered. Each
  # takes the link and the pre-filled words as plain query parameters; no
  # SDK, no script from their side. Mastodon (per-instance) and Instagram
  # have no such URL, so they are left to Copy link.
  @platforms [
    {"X", "https://x.com/intent/post", :text_and_url},
    {"Bluesky", "https://bsky.app/intent/compose", :text_with_url},
    {"Threads", "https://www.threads.net/intent/post", :text_and_url},
    {"Facebook", "https://www.facebook.com/sharer/sharer.php", :u},
    {"LinkedIn", "https://www.linkedin.com/sharing/share-offsite/", :url},
    {"WhatsApp", "https://wa.me/", :text_with_url}
  ]

  attr :id, :string, required: true, doc: "id of the .share_modal the QR code option opens"
  attr :url, :string, required: true
  attr :title, :string, required: true

  attr :text, :string,
    default: nil,
    doc: "words pre-filled on a platform's compose screen; defaults to the title"

  attr :public?, :boolean,
    default: false,
    doc: "offer the platform compose links; off when the link dead-ends for outsiders"

  def share_actions(assigns) do
    assigns = assign(assigns, :platforms, platform_links(assigns))

    ~H"""
    <div id="share-actions" class="side-actions share-actions">
      <button
        type="button"
        id={"#{@id}-native"}
        class="btn-secondary"
        phx-hook="NativeShare"
        phx-update="ignore"
        data-title={@title}
        data-text={@text || @title}
        data-url={@url}
        hidden
      >
        <Icon.icon name="hero-arrow-up-tray" class="size-4" /> Share…
      </button>
      <button
        type="button"
        id={"#{@id}-copy-link"}
        data-value={@url}
        class="btn-secondary"
      >
        <Icon.icon name="hero-link" class="size-4" />
        <span
          id={"#{@id}-copy-link-label"}
          phx-hook="ClipboardCopy"
          phx-update="ignore"
          aria-live="polite"
        >
          Copy link
        </span>
      </button>
      <Button.button id={"#{@id}-email"} variant={:secondary} href={mailto_href(@url, @title)}>
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
      <a
        :for={{name, href} <- @platforms}
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        class="btn-secondary"
      >
        {name}
      </a>
      <p :if={@platforms != []} class="share-platforms-note">
        Instagram and Mastodon: copy the link and paste it there.
      </p>
    </div>
    """
  end

  defp platform_links(%{public?: false}), do: []

  defp platform_links(%{url: url} = assigns) do
    text = assigns.text || assigns.title

    Enum.map(@platforms, fn {name, base, shape} ->
      {name, base <> "?" <> URI.encode_query(compose_params(shape, text, url))}
    end)
  end

  defp compose_params(:text_and_url, text, url), do: [text: text, url: url]
  defp compose_params(:text_with_url, text, url), do: [text: "#{text} #{url}"]
  defp compose_params(:u, _text, url), do: [u: url]
  defp compose_params(:url, _text, url), do: [url: url]

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
          data-value={@url}
          class="btn-secondary"
        >
          <span
            id={"#{@id}-copy-label"}
            phx-hook="ClipboardCopy"
            phx-update="ignore"
            aria-live="polite"
          >
            Copy link
          </span>
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
