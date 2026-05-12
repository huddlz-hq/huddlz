defmodule HuddlzWeb.Components.Modal do
  @moduledoc """
  Centered modal dialog with backdrop. `show_modal/2` and `hide_modal/2` are
  the JS commands callers can pipe to patch the open/closed state. The
  outer `data-cc-modal` attribute is what the sidebar-aware modal-shift
  rule in `app.css` hooks onto so the dialog visually centers within the
  main content area (not the full viewport).
  """
  use Phoenix.Component
  use Gettext, backend: HuddlzWeb.Gettext

  alias HuddlzWeb.Components.Flash
  alias HuddlzWeb.Components.Icon
  alias Phoenix.LiveView.JS

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
                <Icon.icon name="hero-x-mark" class="h-5 w-5" />
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
    |> Flash.show("##{id}-container")
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
    |> Flash.hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
