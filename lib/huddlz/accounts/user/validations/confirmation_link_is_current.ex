defmodule Huddlz.Accounts.User.Validations.ConfirmationLinkIsCurrent do
  @moduledoc """
  A confirmation link minted for an address the account no longer has must
  not confirm the account, and must not put that address back. The
  strategy's own change would apply the stored address; this refuses first.
  """
  use Ash.Resource.Validation

  alias Huddlz.Accounts.Confirmation

  @impl true
  def validate(changeset, _opts, _context) do
    case changeset |> Ash.Changeset.get_argument(:confirm) |> Confirmation.link_state() do
      :previous_address -> {:error, field: :confirm, message: "was for a previous address"}
      _state -> :ok
    end
  end
end
