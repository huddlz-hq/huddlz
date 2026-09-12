defmodule Huddlz.Admin.Impersonation.ResolveSession do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Huddlz.Accounts.User
  alias Huddlz.Admin.Impersonation

  @impl true
  def run(input, _opts, %{actor: %User{id: user_id}}) do
    # This trusted lookup is constrained to the authenticated session's target.
    # The initiating administrator is needed to restore/stop that session.
    case Ash.get(Impersonation, input.arguments.id,
           load: [:admin, :user],
           authorize?: false
         ) do
      {:ok, %Impersonation{user_id: ^user_id, ended_at: nil} = record} ->
        {:ok, record}

      _ ->
        {:ok, nil}
    end
  end

  def run(_input, _opts, _context), do: {:ok, nil}
end
