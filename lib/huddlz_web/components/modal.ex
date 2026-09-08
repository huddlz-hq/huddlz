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
  attr :class, :string, default: "w-full max-w-xl"
  attr :return_focus, :string, default: nil
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      data-cc-modal
      phx-mounted={@show && show_modal(@id)}
      phx-remove={
        if @return_focus, do: hide_modal(@id) |> JS.focus(to: @return_focus), else: hide_modal(@id)
      }
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="modal-backdrop transition-opacity"
        aria-hidden="true"
      />
      <div
        class="modal-layer"
        aria-labelledby={"#{@id}-title"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="modal-center">
          <div class={@class}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="modal-panel"
            >
              {render_slot(@inner_block)}
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="modal-close"
                aria-label={gettext("close")}
              >
                <Icon.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
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
