defmodule HuddlzWeb.Components.PersonMark do
  @moduledoc """
  The app's mark for a person: their picture, or initials on a gradient
  that stays the same for them wherever they appear. Square, unlike the
  round `<.avatar>` the huddl page still uses for its creator line.
  """
  use Phoenix.Component

  attr :user, :map, required: true

  def person_mark(assigns) do
    assigns =
      assigns
      |> assign(:picture, HuddlzWeb.Avatar.picture_url(assigns.user))
      |> assign(:initials, HuddlzWeb.Avatar.initials(assigns.user) || "?")
      |> assign(:variant, "m#{:erlang.phash2(assigns.user.id, 5) + 1}")

    ~H"""
    <div class={["member-mark", @variant]} title={@user.display_name}>
      <img :if={@picture} src={@picture} alt={@user.display_name || ""} />
      <%= if is_nil(@picture) do %>
        {@initials}
      <% end %>
    </div>
    """
  end
end
