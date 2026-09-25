defmodule HuddlzWeb.FormFocus do
  @moduledoc """
  Moves keyboard focus to the first field a failed save marked invalid.

  Call `first_error/2` in the branch that handles a failed submission, with
  the DOM id of the form. The browser focuses the first visible, enabled
  control in that form with `aria-invalid="true"`; `<.input>` already links
  that control to its error text, so a screen reader reads the problem.
  If the failure has no field to fix (a wrong password, say), nothing moves.

  LiveView dispatches pushed events after it patches the page, so the invalid
  fields are in place when the browser looks for them.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  @doc "Ask the browser to focus the first invalid field in the form `form_id`."
  def first_error(socket, form_id) when is_binary(form_id) do
    push_event(socket, "focus-first-error", %{form: form_id})
  end
end
