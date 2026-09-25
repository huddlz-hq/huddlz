// A failed save asks for this from the server (HuddlzWeb.FormFocus). LiveView
// dispatches the event after patching, so the invalid fields are already on
// the page. Hidden and disabled controls can't take focus; skip them.
//
// LiveView blurs the submit button while a form submits and refocuses it
// when the reply's promise settles, just after dispatching this event. Wait
// for the next task so the field's focus comes after that restore.
export function mountFormFocus() {
  window.addEventListener("phx:focus-first-error", ({detail}) => {
    const form = document.getElementById(detail.form)
    if (!form) return

    const field = [...form.querySelectorAll('[aria-invalid="true"]')]
      .find(control => !control.disabled && control.getClientRects().length > 0)

    if (field) setTimeout(() => field.focus())
  })
}
