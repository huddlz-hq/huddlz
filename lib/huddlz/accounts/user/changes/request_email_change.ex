defmodule Huddlz.Accounts.User.Changes.RequestEmailChange do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query

  alias Huddlz.Accounts.EmailChange
  alias Huddlz.Accounts.User

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      email = Ash.Changeset.get_argument(changeset, :email)

      cond do
        Ash.CiString.compare(email, changeset.data.email) == :eq ->
          Ash.Changeset.add_error(changeset,
            field: :email,
            message: "Enter a different email address."
          )

        Ash.exists?(User |> Ash.Query.filter(email == ^email), authorize?: false) ->
          Ash.Changeset.add_error(changeset, field: :email, message: "has already been taken")

        true ->
          pending = %{
            "id" => Ash.UUID.generate(),
            "old_email" => to_string(changeset.data.email),
            "new_email" => to_string(email),
            "expires_at" => System.system_time(:second) + 3 * 24 * 60 * 60,
            "old_approved" => false,
            "new_approved" => false
          }

          Ash.Changeset.force_change_attribute(changeset, :pending_email_change, pending)
      end
    end)
    |> Ash.Changeset.after_action(fn _changeset, user ->
      with :ok <- EmailChange.enqueue(user), do: {:ok, user}
    end)
  end
end
