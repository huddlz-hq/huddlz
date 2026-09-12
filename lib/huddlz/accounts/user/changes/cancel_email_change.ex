defmodule Huddlz.Accounts.User.Changes.CancelEmailChange do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      request_id = Ash.Changeset.get_argument(changeset, :request_id)

      case changeset.data.pending_email_change do
        %{"id" => ^request_id} ->
          Ash.Changeset.force_change_attribute(changeset, :pending_email_change, nil)

        _ ->
          Ash.Changeset.add_error(changeset,
            field: :request_id,
            message: "This email-change request is no longer pending."
          )
      end
    end)
  end
end
