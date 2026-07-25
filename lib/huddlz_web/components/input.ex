defmodule HuddlzWeb.Components.Input do
  @moduledoc """
  V3 form primitives — `input/1`, `textarea/1`, `select/1`.

  Each renders a `form-row` containing a `form-label`, the field control, and
  optional `form-help` / `form-error` text. They accept either a
  `Phoenix.HTML.FormField` via the `field` attr, or a manual `name`/`value`/
  `errors` triple.
  """
  use Phoenix.Component

  alias Phoenix.HTML.Form
  alias Phoenix.HTML.FormField

  attr :field, FormField, required: true
  attr :label, :string, required: true
  attr :show_state_text, :boolean, default: false
  attr :labelled_externally, :boolean, default: false
  attr :disabled, :boolean, default: false

  @doc """
  Renders a native checkbox with switch semantics.

  The input remains in the accessibility tree and keyboard order while the
  visible track receives the focus treatment.
  """
  def toggle(assigns) do
    checked = Form.normalize_value("checkbox", assigns.field.value) == true

    assigns =
      assigns
      |> assign(:checked, checked)
      |> assign(:visible_label, toggle_label(assigns.label, assigns.show_state_text, checked))

    ~H"""
    <div class="toggle">
      <input type="hidden" name={@field.name} value="false" />
      <input
        id={@field.id}
        type="checkbox"
        role="switch"
        name={@field.name}
        value="true"
        checked={@checked}
        aria-checked={to_string(@checked)}
        aria-label={!@labelled_externally && @label}
        disabled={@disabled}
      />
      <span class="track" aria-hidden="true"></span>
      <span class="toggle-text" aria-hidden="true">{@visible_label}</span>
      <label for={@field.id} class="toggle-hitbox" aria-hidden={@labelled_externally}>
        <span :if={!@labelled_externally} class="sr-only">{@label}</span>
      </label>
    </div>
    """
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :help, :string, default: nil
  attr :errors, :list, default: []
  attr :field, FormField, doc: "a Phoenix.HTML.FormField struct"
  attr :class, :any, default: nil
  attr :control_class, :any, default: nil

  slot :prefix
  slot :details

  attr :rest, :global, include: ~w(autocomplete disabled form list max maxlength min minlength
                pattern placeholder readonly required step inputmode)

  def input(%{field: %FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, visible_errors(field))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(assigns) do
    assigns = prepare_accessibility(assigns)

    ~H"""
    <div class="form-row">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <.input_control :if={@prefix == []} {assigns} />
      <div :if={@prefix != []} class={@control_class}>
        {render_slot(@prefix)}
        <.input_control {assigns} />
      </div>
      <p :if={@help} id={help_id(@id)} class="form-help">{@help}</p>
      <p
        :for={{msg, index} <- Enum.with_index(@errors)}
        id={error_id(@id, index)}
        class="form-error"
        role="alert"
      >
        {msg}
      </p>
      {render_slot(@details)}
    </div>
    """
  end

  defp input_control(assigns) do
    ~H"""
    <input
      type={@type}
      id={@id}
      name={@name}
      value={Form.normalize_value(@type, @value)}
      class={["form-input", @class]}
      aria-invalid={@invalid? && "true"}
      aria-describedby={@describedby}
      {@rest}
    />
    """
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :help, :string, default: nil
  attr :errors, :list, default: []
  attr :field, FormField, doc: "a Phoenix.HTML.FormField struct"
  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(autocomplete disabled form maxlength minlength
                placeholder readonly required rows cols)

  def textarea(%{field: %FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, visible_errors(field))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> textarea()
  end

  def textarea(assigns) do
    assigns = prepare_accessibility(assigns)

    ~H"""
    <div class="form-row">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <textarea
        id={@id}
        name={@name}
        class={["form-textarea", @class]}
        aria-invalid={@invalid? && "true"}
        aria-describedby={@describedby}
        {@rest}
      >{Form.normalize_value("textarea", @value)}</textarea>
      <p :if={@help} id={help_id(@id)} class="form-help">{@help}</p>
      <p
        :for={{msg, index} <- Enum.with_index(@errors)}
        id={error_id(@id, index)}
        class="form-error"
        role="alert"
      >
        {msg}
      </p>
    </div>
    """
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :help, :string, default: nil
  attr :errors, :list, default: []
  attr :field, FormField, doc: "a Phoenix.HTML.FormField struct"
  attr :class, :any, default: nil
  attr :options, :list, required: true, doc: "list of {label, value} tuples or values"
  attr :prompt, :string, default: nil

  attr :rest, :global, include: ~w(autocomplete disabled form multiple required size)

  def select(%{field: %FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, visible_errors(field))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> select()
  end

  def select(assigns) do
    assigns = prepare_accessibility(assigns)

    ~H"""
    <div class="form-row">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <select
        id={@id}
        name={@name}
        class={["form-select", @class]}
        aria-invalid={@invalid? && "true"}
        aria-describedby={@describedby}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p :if={@help} id={help_id(@id)} class="form-help">{@help}</p>
      <p
        :for={{msg, index} <- Enum.with_index(@errors)}
        id={error_id(@id, index)}
        class="form-error"
        role="alert"
      >
        {msg}
      </p>
    </div>
    """
  end

  attr :field, FormField, required: true, doc: "form field whose errors to render"
  attr :id, :any, default: nil

  @doc """
  Renders `<p class="form-error">` lines for a form field whose markup isn't
  produced by `input/textarea/select` (e.g. an inline raw input or a
  radio-card group). Hidden until the field has been touched (`used_input?/1`).

  For fields with no client-side input at all (custom pickers), ensure the
  param key is present once errors should show — see
  `HuddlzWeb.HuddlLive.FormHelpers.mark_location_used/2`. LiveView's form
  change tracking only re-renders this component when the field's value,
  errors, or used state change, so visibility must be derived from field
  state, not external flags.
  """
  def field_errors(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> Phoenix.Component.assign(:id, assigns.id || field.id)
      |> Phoenix.Component.assign(:errors, visible_errors(field))

    ~H"""
    <p
      :for={{msg, index} <- Enum.with_index(@errors)}
      id={error_id(@id, index)}
      class="form-error"
      role="alert"
    >
      {msg}
    </p>
    """
  end

  @doc false
  def visible_errors(%FormField{} = field) do
    if Phoenix.Component.used_input?(field) do
      Enum.map(field.errors, &translate_error/1)
    else
      []
    end
  end

  @doc false
  def field_error_ids(%FormField{} = field) do
    field
    |> visible_errors()
    |> Enum.with_index()
    |> Enum.map(fn {_error, index} -> error_id(field.id, index) end)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  defp prepare_accessibility(assigns) do
    assigns = assign_new(assigns, :id, fn -> assigns[:name] end)
    id = assigns[:id]
    errors = assigns[:errors]

    assigns
    |> assign(:invalid?, errors != [])
    |> assign(:describedby, describedby_ids(id, assigns[:help], errors))
  end

  defp describedby_ids(id, help, errors) do
    [
      help && help_id(id)
      | Enum.map(Enum.with_index(errors), fn {_error, index} -> error_id(id, index) end)
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp help_id(id), do: "#{id}-help"
  defp error_id(id, index), do: "#{id}-error-#{index}"

  defp toggle_label(_label, true, true), do: "On"
  defp toggle_label(_label, true, false), do: "Off"
  defp toggle_label(label, false, _checked), do: label
end
