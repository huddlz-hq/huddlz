defmodule HuddlzWeb.Components.CoverImage do
  @moduledoc """
  Decorative cover media layered over the surrounding fallback.

  A missing or failed CSS background leaves the fallback visible without any
  server-side state. The `CoverImage` hook layers a loading surface over the
  element while the picture is still arriving and records the outcome in
  `data-cover-state`; without JavaScript the picture simply paints when ready.
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :image_url, :string, required: true
  attr :class, :any, required: true

  def cover_image(assigns) do
    url = Huddlz.Storage.url(assigns.image_url)
    css_url = URI.encode(url, &(URI.char_unescaped?(&1) or &1 == ?%))

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:background, ~s|background-image: url("#{css_url}")|)

    ~H"""
    <div
      id={@id}
      class={["cover-image", @class]}
      style={@background}
      data-cover-url={@url}
      phx-hook="CoverImage"
      aria-hidden="true"
    >
    </div>
    """
  end
end
