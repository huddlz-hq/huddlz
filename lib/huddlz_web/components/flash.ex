defmodule HuddlzWeb.Components.Flash do
  @moduledoc """
  Flash toast rendering plus the `show/2` / `hide/2` JS animation helpers
  it shares with the layout's client-error banner. Toasts stack top-right
  (see `.flash-group` in app.css), slide in, and fade out on dismiss.
  """
  use Phoenix.Component
  use Gettext, backend: HuddlzWeb.Gettext

  alias HuddlzWeb.Components.Icon
  alias Phoenix.LiveView.JS

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
      class={["flash", "flash-#{@kind}"]}
      {@rest}
    >
      <span class="flash-icon" aria-hidden="true">
        <Icon.icon :if={@kind == :info} name="hero-check-circle" class="size-5" />
        <Icon.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5" />
      </span>
      <div class="flash-body">
        <p :if={@title} class="flash-title">{@title}</p>
        <span>{msg}</span>
      </div>
      <button type="button" class="flash-close" aria-label={gettext("close")}>
        <Icon.icon name="hero-x-mark" class="size-4" />
      </button>
    </div>
    """
  end

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
end
