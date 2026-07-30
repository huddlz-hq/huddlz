defmodule Huddlz.Communities.GroupInvitation.Changes.LockPending do
  @moduledoc """
  Serializes invitation transitions and validates the persisted pending state.

  LiveViews can hold an invitation after another session accepts, declines,
  revokes, or expires it. Locking and checking the database row inside the
  action transaction prevents a stale struct from overwriting that transition.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Communities.GroupInvitation

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, &lock_and_validate(&1, opts[:expiration]))
  end

  defp lock_and_validate(changeset, expiration) do
    invitation =
      GroupInvitation
      |> Ash.Query.filter(id == ^changeset.data.id)
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read_one!(authorize?: false)

    if valid_transition?(invitation, expiration) do
      changeset
    else
      Ash.Changeset.add_error(
        changeset,
        field: :status,
        message: invalid_message(invitation, expiration)
      )
    end
  end

  defp valid_transition?(%{status: :pending, expires_at: expires_at}, :future),
    do: DateTime.compare(expires_at, DateTime.utc_now()) == :gt

  defp valid_transition?(%{status: :pending, expires_at: expires_at}, :past),
    do: DateTime.compare(expires_at, DateTime.utc_now()) != :gt

  defp valid_transition?(_invitation, _expiration), do: false

  defp invalid_message(%{status: status}, _expiration) when status != :pending,
    do: "is no longer pending"

  defp invalid_message(_invitation, :future), do: "has expired"
  defp invalid_message(_invitation, :past), do: "has not expired"
end
