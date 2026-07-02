defmodule HuddlzWeb.Components.Avatar do
  @moduledoc """
  Renders a user avatar with fallback to initials or icon.
  """
  use Phoenix.Component

  alias HuddlzWeb.Components.Icon

  attr :user, :map,
    default: nil,
    doc: "User struct with current_profile_picture_url and display_name"

  attr :size, :atom, default: :md, values: [:xs, :sm, :md, :lg, :xl]
  attr :class, :string, default: nil

  def avatar(assigns) do
    size_classes = %{
      xs: "w-6 h-6 text-xs",
      sm: "w-8 h-8 text-sm",
      md: "w-10 h-10 text-base",
      lg: "w-12 h-12 text-lg",
      xl: "w-32 h-32 text-3xl"
    }

    icon_sizes = %{
      xs: "w-3 h-3",
      sm: "w-4 h-4",
      md: "w-5 h-5",
      lg: "w-6 h-6",
      xl: "w-16 h-16"
    }

    assigns =
      assigns
      |> assign(:size_class, size_classes[assigns.size])
      |> assign(:icon_size, icon_sizes[assigns.size])
      |> assign(:initials, HuddlzWeb.Avatar.initials(assigns.user))
      |> assign(:avatar_url, HuddlzWeb.Avatar.picture_url(assigns.user))

    ~H"""
    <div class={[
      "flex items-center justify-center flex-shrink-0 overflow-hidden rounded-full",
      @size_class,
      @class
    ]}>
      <%= cond do %>
        <% @avatar_url -> %>
          <img src={@avatar_url} alt={get_display_name(@user)} class="w-full h-full object-cover" />
        <% @initials -> %>
          <div class="w-full h-full flex items-center justify-center bg-primary text-primary-content font-semibold">
            {@initials}
          </div>
        <% true -> %>
          <div class="w-full h-full flex items-center justify-center bg-base-300 text-base-content/50">
            <Icon.icon name="hero-user" class={@icon_size} />
          </div>
      <% end %>
    </div>
    """
  end

  defp get_display_name(nil), do: "User"
  defp get_display_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp get_display_name(%{email: email}), do: email
  defp get_display_name(_), do: "User"
end
