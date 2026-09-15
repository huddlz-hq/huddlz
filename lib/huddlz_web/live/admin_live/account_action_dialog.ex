defmodule HuddlzWeb.AdminLive.AccountActionDialog do
  @moduledoc """
  The one confirmation dialog for account administration: suspend (with
  its reason), restore, and the administrator role. Users and Reports
  open it with an `action` of `%{type, user, form}`; the LiveView answers
  `validate_action`, `confirm_action` and `cancel_action`.
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Button
  import HuddlzWeb.Components.Input
  import HuddlzWeb.Components.Modal

  alias Phoenix.LiveView.JS

  @doc "The dialog's action for suspending or restoring `user`, with its form."
  def account_action(type, user, actor) when type in [:suspend, :restore] do
    form = AshPhoenix.Form.for_update(user, type, actor: actor, as: "form")
    %{type: type, user: user, form: Phoenix.Component.to_form(form)}
  end

  attr :action, :map, required: true

  def account_action_dialog(assigns) do
    ~H"""
    <.modal id="account-action-dialog" show on_cancel={JS.push("cancel_action")}>
      <div class="pr-8">
        <h2 id="account-action-dialog-title" class="text-xl font-bold text-base-content">
          {action_title(@action)}
        </h2>
        <p class="mt-3 text-sm leading-6 text-base-content/70">{action_description(@action)}</p>
        <ul :if={action_effects(@action.type) != []} class="leave-confirm-list">
          <li :for={effect <- action_effects(@action.type)}>{effect}</li>
        </ul>
      </div>

      <.form
        for={@action.form || %{}}
        id="account-action-form"
        phx-submit="confirm_action"
        phx-change="validate_action"
        class="mt-6"
      >
        <.textarea
          :if={@action.type == :suspend}
          field={@action.form[:reason]}
          id="suspend-reason"
          label="Reason"
          rows="3"
          placeholder="What happened, in a sentence or two."
          help="Kept with the account and shown only to administrators. Reports and reporters stay out of the email."
        />

        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <.button id="account-action-cancel" phx-click="cancel_action">Cancel</.button>
          <.button
            id="account-action-confirm"
            type="submit"
            variant={if @action.type == :suspend, do: :destructive, else: :primary}
            phx-disable-with="Saving..."
          >
            {action_confirm_label(@action.type)}
          </.button>
        </div>
      </.form>
    </.modal>
    """
  end

  defp action_title(%{type: :suspend, user: user}), do: "Suspend #{user.display_name}?"
  defp action_title(%{type: :restore, user: user}), do: "Restore #{user.display_name}?"

  defp action_title(%{type: :make_admin, user: user}),
    do: "Make #{user.display_name} an administrator?"

  defp action_title(%{type: :remove_admin, user: user}),
    do: "Remove #{user.display_name} as an administrator?"

  defp action_description(%{type: :suspend}),
    do:
      "Their access ends now, on every device and API key, and stays off until an administrator restores it."

  defp action_description(%{type: :restore}),
    do:
      "Only for a suspension that was a mistake. Proof that a person is at the keyboard is not enough on its own."

  defp action_description(%{type: :make_admin}),
    do:
      "Administrators manage accounts and see the platform overview. Their group roles do not change."

  defp action_description(%{type: :remove_admin}),
    do: "They keep their account and group roles and lose the admin area."

  defp action_effects(:suspend),
    do: [
      "Upcoming RSVP and waitlist spots are released. History is kept.",
      "Other members see “Suspended account” instead of their name and picture.",
      "Their groups and huddlz stay and are flagged for review.",
      "They get one email with the support address. Nothing from this form is in it."
    ]

  defp action_effects(:restore),
    do: [
      "They can sign in again from scratch. Old sessions and API keys stay revoked.",
      "Their name and picture come back everywhere.",
      "Released RSVP and waitlist spots are not rebooked."
    ]

  defp action_effects(_type), do: []

  defp action_confirm_label(:suspend), do: "Suspend account"
  defp action_confirm_label(:restore), do: "Restore account"
  defp action_confirm_label(:make_admin), do: "Make an administrator"
  defp action_confirm_label(:remove_admin), do: "Remove as administrator"
end
