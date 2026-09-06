defmodule HuddlzWeb.Components.CoverImage do
  @moduledoc """
  Decorative cover media layered over the surrounding fallback.

  A missing or failed CSS background leaves the fallback visible without
  client-side state or image load handlers.
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :image_url, :string, required: true
  attr :class, :any, required: true

  def cover_image(assigns) do
    url =
      assigns.image_url
      |> Huddlz.Storage.url()
      |> URI.encode(&(URI.char_unescaped?(&1) or &1 == ?%))

    assigns = assign(assigns, :background, ~s|background-image: url("#{url}")|)

    ~H"""
    <div id={@id} class={["cover-image", @class]} style={@background} aria-hidden="true"></div>
    """
  end
end
