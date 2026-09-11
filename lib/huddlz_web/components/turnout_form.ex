defmodule HuddlzWeb.Components.TurnoutForm do
  @moduledoc """
  The one turnout form, opened in place wherever an organizer reviews past
  huddlz: under the overview reminder or inside a past row on the huddlz
  list. The LiveView keeps a single open editor, `%{huddl: huddl, form:
  form}`, and handles `edit_turnout`, `cancel_turnout`, `validate_turnout`,
  `record_turnout` and `skip_turnout`; the form carries its huddl's id.

  See ADR 0003: turnout is a headcount, never per-person check-in.
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Button
  import HuddlzWeb.Components.Input

  attr :id, :string, required: true
  attr :huddl, :map, required: true
  attr :form, :any, required: true, doc: "the `record_turnout` form, from `build/2`"

  def turnout_form(assigns) do
    ~H"""
    <div class="turnout turnout-inline">
      <.form for={@form} id={@id} phx-change="validate_turnout" phx-submit="record_turnout">
        <input type="hidden" name="huddl_id" value={@huddl.id} />
        <div class="turnout-copy">
          <h2>{question(@huddl)}</h2>
          <p>A rough count is fine. Count everyone, not just who RSVPd.</p>
        </div>
        <div class="turnout-fields">
          <.input
            :if={@huddl.event_type in [:in_person, :hybrid]}
            field={@form[:in_room]}
            type="number"
            label="People in the room"
            min="0"
            inputmode="numeric"
          />
          <.input
            :if={@huddl.event_type in [:virtual, :hybrid]}
            field={@form[:on_call]}
            type="number"
            label="People on the call"
            min="0"
            inputmode="numeric"
          />
        </div>
        <div class="turnout-actions">
          <.button type="submit" variant={:primary} phx-disable-with="Saving…">
            Save turnout
          </.button>
          <.button
            :if={is_nil(@huddl.turnout_recorded_at)}
            variant={:secondary}
            phx-click="skip_turnout"
            phx-value-id={@huddl.id}
          >
            Skip for now
          </.button>
          <.button variant={:secondary} phx-click="cancel_turnout">Cancel</.button>
        </div>
        <p
          :for={{:base, message} <- AshPhoenix.Form.errors(@form, format: :simple)}
          class="form-error"
          role="alert"
        >
          {message}
        </p>
      </.form>
    </div>
    """
  end

  @doc "The form for recording this huddl's turnout, seeded with what is already recorded."
  def build(huddl, user) do
    huddl
    |> AshPhoenix.Form.for_update(:record_turnout,
      actor: user,
      as: "turnout",
      params: recorded(huddl)
    )
    |> to_form()
  end

  def question(%{event_type: :virtual}), do: "How many joined?"
  def question(_huddl), do: "How many came?"

  defp recorded(huddl) do
    %{"in_room" => huddl.turnout_in_room, "on_call" => huddl.turnout_on_call}
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
