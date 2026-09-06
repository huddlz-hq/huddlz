defmodule HuddlzWeb.Components.HuddlCoverImage do
  @moduledoc """
  Renders decorative huddl cover media with the shared browser fallback contract.

  Failed images are hidden by the delegated handlers in `assets/js/app.js`, which
  reveals the gradient supplied by the surrounding hero or card.
  """
  use Phoenix.Component

  alias Huddlz.Storage.HuddlImages

  attr :id, :string, required: true
  attr :image_url, :string, required: true
  attr :class, :any, required: true

  def huddl_cover_image(assigns) do
    ~H"""
    <img
      id={@id}
      class={@class}
      src={HuddlImages.url(@image_url)}
      alt=""
      data-image-fallback
    />
    """
  end
end
