defmodule HuddlzWeb.Components.Flash do
  @moduledoc """
  Flash notice rendering plus the `show/2` / `hide/2` JS animation helpers
  it shares with the layout's client-error banner. Slides in from the top,
  fades out on dismiss.
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
        <Icon.icon :if={@kind == :info} name="hero-information-circle-mini" class="size-5 shrink-0" />
        <Icon.icon
          :if={@kind == :error}
          name="hero-exclamation-circle-mini"
          class="size-5 shrink-0"
        />
        <span class="flex-1">
          <span :if={@title} class="font-semibold">{@title}: </span>{msg}
        </span>
        <button
          type="button"
          class="opacity-50 hover:opacity-100 transition-opacity"
          aria-label={gettext("close")}
        >
          <Icon.icon name="hero-x-mark-solid" class="size-4" />
        </button>
      </div>
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
