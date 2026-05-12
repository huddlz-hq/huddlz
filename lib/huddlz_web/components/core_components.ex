defmodule HuddlzWeb.CoreComponents do
  @moduledoc """
  Surviving Phoenix core components: `flash/1`, `icon/1`, `avatar/1`,
  `modal/1` and its `show_modal/2`/`hide_modal/2` JS commands.

  Everything else (button, input, table, pagination, the form-field
  pickers, etc.) was replaced by `HuddlzWeb.Components.*` during the v3 migration.
  These four are the last holdouts — modal and flash will likely follow.
  """
  use Phoenix.Component
  use Gettext, backend: HuddlzWeb.Gettext

  alias Huddlz.Storage.ProfilePictures
  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="w-full cursor-pointer mb-4"
      {@rest}
    >
      <div class={[
        "flex items-center gap-3 border rounded-hz-surface px-4 py-3 text-sm",
        @kind == :info && "border-primary/30 bg-primary/5 text-primary",
        @kind == :error && "border-error/30 bg-error/5 text-error"
      ]}>
        <div class={[
          "w-1 self-stretch",
          @kind == :info && "bg-primary",
          @kind == :error && "bg-error"
        ]} />
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="size-5 shrink-0" />
        <span class="flex-1">
          <span :if={@title} class="font-semibold">{@title}: </span>{msg}
        </span>
        <button
          type="button"
          class="opacity-50 hover:opacity-100 transition-opacity"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark-solid" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a user avatar with fallback to initials or icon.
  """
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
      |> assign(:initials, get_initials(assigns.user))
      |> assign(:avatar_url, get_avatar_url(assigns.user))

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
            <.icon name="hero-user" class={@icon_size} />
          </div>
      <% end %>
    </div>
    """
  end

  defp get_initials(nil), do: nil
  defp get_initials(%{display_name: nil}), do: nil
  defp get_initials(%{display_name: ""}), do: nil

  defp get_initials(%{display_name: name}) do
    name
    |> String.trim()
    |> String.split(~r/\s+/)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp get_initials(_), do: nil

  defp get_avatar_url(nil), do: nil

  defp get_avatar_url(%{current_profile_picture_url: url})
       when is_binary(url) and url != "" do
    ProfilePictures.url(url)
  end

  defp get_avatar_url(_), do: nil

  defp get_display_name(nil), do: "User"
  defp get_display_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp get_display_name(%{email: email}), do: email
  defp get_display_name(_), do: "User"

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders a modal dialog as an overlay.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      data-cc-modal
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-base-100/80 fixed inset-0 backdrop-blur-sm transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-xl">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="relative border border-base-300 bg-base-200 rounded-hz-modal shadow-pop p-6"
            >
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="absolute top-4 right-4 text-base-content/40 hover:text-base-content transition-colors"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
              {render_slot(@inner_block)}
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
