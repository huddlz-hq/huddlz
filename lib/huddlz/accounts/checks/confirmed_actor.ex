defmodule Huddlz.Accounts.Checks.ConfirmedActor do
  @moduledoc """
  Requires current proof of address ownership, even for an actor loaded
  before the account became unconfirmed. Tokens identify an account;
  they do not freeze its eligibility to participate.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Accounts.User

  @impl true
  def describe(_opts), do: "confirm your email before participating"

  @impl true
  def match?(%{id: id}, _context, _opts) do
    case Ash.get(User, id, authorize?: false) do
      {:ok, %User{confirmed_at: %DateTime{}}} -> true
      _ -> false
    end
  end

  def match?(_actor, _context, _opts), do: false
end
