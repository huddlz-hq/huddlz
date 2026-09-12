defmodule Huddlz.Accounts.User.Changes.ResendEmailChange do
  @moduledoc false
  use Ash.Resource.Change
  alias Huddlz.Accounts.EmailChange

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(&resend/1)
    |> Ash.Changeset.after_action(fn _changeset, user ->
      with :ok <- EmailChange.enqueue(user), do: {:ok, user}
    end)
  end

  defp resend(changeset) do
    user = changeset.data
    now = System.system_time(:second)
    recent = Enum.filter(user.email_change_resends, &(&1 > now - 3600))
    request_id = Ash.Changeset.get_argument(changeset, :request_id)

    cond do
      not EmailChange.active?(user.pending_email_change) or
          user.pending_email_change["id"] != request_id ->
        Ash.Changeset.add_error(changeset,
          field: :request_id,
          message: "This request has expired or is no longer pending. Request a new email change."
        )

      length(recent) >= 5 or Enum.any?(recent, &(&1 > now - 60)) ->
        Ash.Changeset.add_error(changeset,
          field: :request_id,
          message: "Wait a minute between resends; at most five are allowed per hour."
        )

      true ->
        Ash.Changeset.force_change_attribute(changeset, :email_change_resends, [now | recent])
    end
  end
end
