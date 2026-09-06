defmodule Huddlz.Communities.GroupMember.Validations.CurrentOwnerCannotChangeRole do
  @moduledoc """
  Requires ownership transfer instead of changing the current owner's membership role.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, _opts, _context) do
    if changeset.data.role == :owner do
      {:error, field: :role, message: "the group owner cannot be demoted"}
    else
      :ok
    end
  end
end
