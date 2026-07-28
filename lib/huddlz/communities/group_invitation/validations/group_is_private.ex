defmodule Huddlz.Communities.GroupInvitation.Validations.GroupIsPrivate do
  @moduledoc false

  use Ash.Resource.Validation

  require Ash.Query

  alias Huddlz.Communities.Group

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    group_id = Ash.Changeset.get_argument(changeset, :group_id)

    Group
    |> Ash.Query.filter(id == ^group_id and is_public == false)
    |> Ash.exists?(authorize?: false)
    |> case do
      true -> :ok
      false -> {:error, field: :group_id, message: "must belong to a private group"}
    end
  end
end
