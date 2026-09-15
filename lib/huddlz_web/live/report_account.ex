defmodule HuddlzWeb.ReportAccount do
  @moduledoc """
  Reporting an account from wherever a member can already see a person:
  the who's going list, a group's member grid, a huddl's organized-by
  line and the organizer roster. One menu item, one dialog, one thanks.

  A LiveView mounts `on_mount HuddlzWeb.ReportAccount` to answer the
  dialog's events, renders `<.person_menu>` (or `<.report_menu>` behind
  its own trigger) next to each person it may offer the item for, and
  `<.report_account_dialog>` once. Who may report whom is decided by
  `Huddlz.Accounts.AccountReport`; `offer?/3` only keeps the item off
  people it could never apply to.
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Button
  import HuddlzWeb.Components.Icon
  import HuddlzWeb.Components.Input, only: [textarea: 1, visible_errors: 1]
  import HuddlzWeb.Components.Modal
  import Phoenix.LiveView

  alias Huddlz.Accounts
  alias Huddlz.Accounts.{AccountReport, User}
  alias Phoenix.LiveView.JS

  @thanks "Thanks—we've received your report."

  @doc "The one reporter-facing message."
  def thanks, do: @thanks

  @doc """
  Whether to show "Report account" for this person at all: the viewer is
  a confirmed member, not an administrator (they suspend from Users), and
  the person is someone else whose account is not already suspended.
  """
  def offer?(%User{} = viewer, person_id, suspended?) when is_binary(person_id) do
    not is_nil(viewer.confirmed_at) and not User.admin?(viewer) and
      viewer.id != person_id and not suspended?
  end

  def offer?(_viewer, _person_id, _suspended?), do: false

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:report, nil)
     |> attach_hook(:report_account, :handle_event, &handle_report_event/3)}
  end

  defp handle_report_event("open_report", params, socket) do
    {:halt, open(socket, params)}
  end

  defp handle_report_event("validate_report", %{"report" => params}, socket) do
    {:halt, update_report(socket, &%{&1 | form: AshPhoenix.Form.validate(&1.form, params)})}
  end

  defp handle_report_event("submit_report", params, socket) do
    {:halt, submit(socket, params["report"] || %{})}
  end

  defp handle_report_event("cancel_report", _params, socket) do
    {:halt, assign(socket, :report, nil)}
  end

  defp handle_report_event(_event, _params, socket), do: {:cont, socket}

  defp open(socket, %{"user-id" => user_id} = params) do
    viewer = socket.assigns[:current_user]

    with true <- offer?(viewer, user_id, false),
         {:ok, %User{} = user} <- Accounts.get_user_for_others(user_id, actor: viewer),
         false <- User.suspended?(user) do
      source = %{
        "reported_user_id" => user.id,
        "source_type" => params["source-type"],
        "source_id" => params["source-id"]
      }

      form =
        AshPhoenix.Form.for_create(AccountReport, :report,
          actor: viewer,
          as: "report",
          transform_params: fn _form, params, _phase -> Map.merge(params, source) end
        )

      assign(socket, :report, %{user: user, form: to_form(form)})
    else
      _ -> put_flash(socket, :error, "That account cannot be reported.")
    end
  end

  defp open(socket, _params), do: socket

  defp submit(%{assigns: %{report: nil}} = socket, _params), do: socket

  # A submit with no choice carries no "reason" param at all; naming it
  # marks the field as used so its error shows.
  defp submit(%{assigns: %{report: report}} = socket, params) do
    case AshPhoenix.Form.submit(report.form, params: Map.put_new(params, "reason", "")) do
      {:ok, _report} ->
        socket |> assign(:report, nil) |> put_flash(:info, @thanks)

      {:error, form} ->
        if field_errors?(form) do
          assign(socket, :report, %{report | form: form})
        else
          socket |> assign(:report, nil) |> put_flash(:error, "That account cannot be reported.")
        end
    end
  end

  defp field_errors?(form) do
    form
    |> AshPhoenix.Form.errors()
    |> Enum.any?(fn {field, _message} -> field in [:reason, :details] end)
  end

  defp update_report(%{assigns: %{report: nil}} = socket, _fun), do: socket
  defp update_report(socket, fun), do: assign(socket, :report, fun.(socket.assigns.report))

  # ── components ──────────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :user_id, :string, required: true
  attr :source, :any, required: true, doc: "`{:huddl, id}` or `{:group, id}`"
  attr :class, :any, default: nil

  @doc "A ⋯ trigger and the one-item menu behind it."
  def person_menu(assigns) do
    ~H"""
    <div class={["member-menu person-menu", @class]}>
      <button
        type="button"
        id={"#{@id}-trigger"}
        class="icon-pill member-menu-trigger"
        popovertarget={@id}
        aria-label={"Manage #{@name}"}
        aria-haspopup="menu"
      >
        <.icon name="hero-ellipsis-horizontal" class="size-4" />
      </button>
      <.report_menu id={@id} name={@name} user_id={@user_id} source={@source} />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :user_id, :string, required: true
  attr :source, :any, required: true

  @doc "The popover menu alone, for a caller that supplies its own trigger."
  def report_menu(assigns) do
    ~H"""
    <div
      id={@id}
      class="row-menu"
      popover="auto"
      role="menu"
      aria-label={"Manage #{@name}"}
      phx-hook="PopoverMenu"
    >
      <.report_menu_item menu={@id} user_id={@user_id} source={@source} />
    </div>
    """
  end

  attr :menu, :string, required: true
  attr :user_id, :string, required: true
  attr :source, :any, required: true
  attr :divider, :boolean, default: false

  @doc "The \"Report account\" item, for a menu that already has others."
  def report_menu_item(assigns) do
    {source_type, source_id} = assigns.source
    assigns = assign(assigns, source_type: source_type, source_id: source_id)

    ~H"""
    <hr :if={@divider} class="row-menu-divider" role="separator" />
    <button
      type="button"
      id={"#{@menu}-report"}
      class="row-menu-item"
      role="menuitem"
      phx-click="open_report"
      phx-value-user-id={@user_id}
      phx-value-source-type={@source_type}
      phx-value-source-id={@source_id}
      popovertarget={@menu}
      popovertargetaction="hide"
    >
      <.icon name="hero-flag" class="size-4 row-menu-icon" /> Report account
    </button>
    """
  end

  attr :report, :map, required: true

  def report_account_dialog(assigns) do
    assigns =
      assigns
      |> assign(:form, assigns.report.form)
      |> assign(:name, assigns.report.user.display_name)
      |> assign(:reason_errors, visible_errors(assigns.report.form[:reason]))

    ~H"""
    <.modal id="report-account-dialog" show on_cancel={JS.push("cancel_report")}>
      <div class="report-head">
        <span class="report-flag" aria-hidden="true"><.icon name="hero-flag" class="size-5" /></span>
        <div class="pr-8">
          <h2 id="report-account-dialog-title" class="text-xl font-bold text-base-content">
            Report {@name}?
          </h2>
          <p class="mt-3 text-sm leading-6 text-base-content/70">
            Only trusted huddlz staff can review your report and see who sent it. We won't notify {@name}, and you won't get a follow-up.
          </p>
        </div>
      </div>

      <.form
        for={@form}
        id="report-account-form"
        phx-submit="submit_report"
        phx-change="validate_report"
        class="mt-6"
      >
        <fieldset
          class="report-reasons"
          aria-describedby={@reason_errors != [] && "report-reason-error"}
        >
          <legend class="form-label">What's wrong</legend>
          <.reason_option
            field={@form[:reason]}
            value="spam"
            title="Spam or advertising"
            desc="Promotions, coin listings, affiliate links, fake huddlz."
            invalid={@reason_errors != []}
          />
          <.reason_option
            field={@form[:reason]}
            value="other"
            title="Other"
            desc="Anything else an administrator should look at."
            invalid={@reason_errors != []}
          />
          <p
            :for={msg <- @reason_errors}
            id="report-reason-error"
            class="form-error report-reason-error"
            role="alert"
          >
            <.icon name="hero-exclamation-triangle" class="size-4" /> {msg}
          </p>
        </fieldset>

        <.textarea
          field={@form[:details]}
          id="report-details"
          label="Details"
          rows="3"
          placeholder="What you saw, in a sentence or two."
          help="Optional. Shared with trusted huddlz staff along with your name."
        />

        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <.button id="report-account-cancel" phx-click="cancel_report">Cancel</.button>
          <.button
            id="report-account-confirm"
            type="submit"
            variant={:primary}
            phx-disable-with="Sending..."
          >
            <.icon name="hero-flag" class="size-4" /> Report account
          </.button>
        </div>
      </.form>
    </.modal>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :value, :string, required: true
  attr :title, :string, required: true
  attr :desc, :string, required: true
  attr :invalid, :boolean, default: false

  defp reason_option(assigns) do
    assigns =
      assigns
      |> assign(:radio_id, "report-reason-#{assigns.value}")
      |> assign(:checked, to_string(assigns.field.value) == assigns.value)

    ~H"""
    <div class={["report-option", @checked && "is-active", @invalid && "is-invalid"]}>
      <input
        id={@radio_id}
        type="radio"
        name={@field.name}
        value={@value}
        checked={@checked}
        class="choice-control-input"
        aria-invalid={@invalid && "true"}
      />
      <span class="report-option-radio" aria-hidden="true"></span>
      <span class="report-option-copy">
        <label for={@radio_id} class="report-option-title">{@title}</label>
        <span class="report-option-desc">{@desc}</span>
      </span>
    </div>
    """
  end
end
