defmodule Huddlz.Accounts.User.Changes.ReportEmailChange do
  @moduledoc false
  use Ash.Resource.Change
  require Logger
  alias Huddlz.Accounts.EmailChange

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      with {:ok, {user_id, request_id, side}} <-
             EmailChange.verify(Ash.Changeset.get_argument(changeset, :token)),
           true <- user_id == changeset.data.id,
           %{"id" => ^request_id} = pending <- changeset.data.pending_email_change,
           true <- EmailChange.active?(pending),
           false <- pending[side <> "_approved"] do
        Ash.Changeset.force_change_attribute(changeset, :pending_email_change, nil)
      else
        _ ->
          Ash.Changeset.add_error(changeset,
            field: :token,
            message: "This request is no longer pending."
          )
      end
    end)
    |> Ash.Changeset.after_transaction(fn _changeset, result ->
      case result do
        {:ok, user} ->
          Logger.warning(
            "Unexpected email-change request reported and cancelled for account #{user.id}"
          )

        _ ->
          :ok
      end

      result
    end)
  end
end
