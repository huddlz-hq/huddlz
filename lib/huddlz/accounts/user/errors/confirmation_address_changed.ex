defmodule Huddlz.Accounts.User.Errors.ConfirmationAddressChanged do
  @moduledoc "The address in the confirmation link no longer matches the account."
  use Splode.Error, fields: [], class: :invalid

  def message(_), do: "the confirmation link does not match the account's current email"
end
