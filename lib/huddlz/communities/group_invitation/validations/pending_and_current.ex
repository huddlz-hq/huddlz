defmodule Huddlz.Communities.GroupInvitation.Validations.PendingAndCurrent do
  @moduledoc false

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    invitation = changeset.data

    cond do
      invitation.status != :pending ->
        {:error, field: :status, message: "is no longer pending"}

      DateTime.compare(invitation.expires_at, DateTime.utc_now()) != :gt ->
        {:error, field: :expires_at, message: "has expired"}

      true ->
        :ok
    end
  end
end
