defmodule Huddlz.Communities.GroupMember.Validations.AssignableRole do
  @moduledoc """
  Prevents the public membership action from assigning the protected owner role.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :role) do
      role when role in ["member", "organizer"] ->
        :ok

      _ ->
        {:error,
         field: :role,
         message: "must be \"member\" or \"organizer\" (use transfer_ownership to set the owner)"}
    end
  end
end
