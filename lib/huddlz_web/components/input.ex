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

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :help, :string, default: nil
  attr :errors, :list, default: []
  attr :field, FormField, doc: "a Phoenix.HTML.FormField struct"
  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(autocomplete disabled form list max maxlength min minlength
                pattern placeholder readonly required step inputmode)

  def input(%{field: %FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(assigns) do
    assigns = assign_new(assigns, :id, fn -> assigns[:name] end)

    ~H"""
    <div class="form-row">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <input
        type={@type}
        id={@id}
        name={@name}
        value={Form.normalize_value(@type, @value)}
        class={["form-input", @class]}
        {@rest}
      />
      <p :if={@help && @errors == []} class="form-help">{@help}</p>
      <p :for={msg <- @errors} class="form-error">{msg}</p>
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

  attr :rest, :global, include: ~w(autocomplete disabled form maxlength minlength
                placeholder readonly required rows cols)

  def textarea(%{field: %FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> textarea()
  end

  def textarea(assigns) do
    assigns = assign_new(assigns, :id, fn -> assigns[:name] end)

    ~H"""
    <div class="form-row">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <textarea id={@id} name={@name} class={["form-textarea", @class]} {@rest}>{Form.normalize_value("textarea", @value)}</textarea>
      <p :if={@help && @errors == []} class="form-help">{@help}</p>
      <p :for={msg <- @errors} class="form-error">{msg}</p>
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
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> select()
  end

  def select(assigns) do
    assigns = assign_new(assigns, :id, fn -> assigns[:name] end)

    ~H"""
    <div class="form-row">
      <label :if={@label} for={@id} class="form-label">{@label}</label>
      <select id={@id} name={@name} class={["form-select", @class]} {@rest}>
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p :if={@help && @errors == []} class="form-help">{@help}</p>
      <p :for={msg <- @errors} class="form-error">{msg}</p>
    </div>
    """
  end

  attr :field, FormField, required: true, doc: "form field whose errors to render"

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
    errors =
      if Phoenix.Component.used_input?(field) do
        Enum.map(field.errors, &translate_error/1)
      else
        []
      end

    assigns = Phoenix.Component.assign(assigns, :errors, errors)

    ~H"""
    <p :for={msg <- @errors} class="form-error">{msg}</p>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
