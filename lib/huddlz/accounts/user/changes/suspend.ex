defmodule Huddlz.Accounts.User.Changes.Suspend do
  @moduledoc """
  Everything a suspension sets in motion once the account is marked.

  Inside the transaction: every stored token is revoked, so existing
  sessions and bearer tokens die with the row; API keys are destroyed, so
  a later restoration cannot revive them; and upcoming RSVP and waitlist
  spots are released, with the ordinary waitlist rules filling any seat
  that opens. After the transaction commits: one plain notice goes to the
  person; `Huddlz.Accounts.SuspensionEvents` tells open pages to sign out.

  Everything a nested write records is attributed to the administrator
  through `Huddlz.Audit.nested_opts/2`.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.{ApiKey, Token, User}
  alias Huddlz.Communities.ReleaseSpots
  alias Huddlz.Notifications

  require Ash.Query
  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.after_action(&cut_access/2)
    |> Ash.Changeset.after_transaction(&notify/2)
  end

  defp cut_access(changeset, %User{} = user) do
    revoke_tokens(user)
    destroy_api_keys(changeset, user)
    ReleaseSpots.release_upcoming(user, Huddlz.Audit.nested_opts(changeset))
    {:ok, user}
  end

  defp revoke_tokens(user) do
    subject = AshAuthentication.user_to_subject(user)

    %{status: :success} =
      Token
      |> Ash.bulk_update(:revoke_all_stored_for_subject, %{subject: subject},
        authorize?: false,
        strategy: [:atomic, :atomic_batches, :stream],
        return_errors?: true,
        stop_on_error?: true
      )

    :ok
  end

  defp destroy_api_keys(changeset, user) do
    ApiKey
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn key ->
      key
      |> Ash.Changeset.for_destroy(:destroy, %{}, Huddlz.Audit.nested_opts(changeset))
      |> Ash.destroy!(authorize?: false)
    end)
  end

  defp notify(_changeset, {:ok, %User{} = user}) do
    case Notifications.deliver(user, :account_suspended) do
      {:ok, _job} -> :ok
      {:error, reason} -> Logger.error("Failed to enqueue suspension notice: #{inspect(reason)}")
    end

    {:ok, user}
  end

  defp notify(_changeset, result), do: result
end
