defmodule Huddlz.Communities.GroupInvitation.OpenEmailInvitation do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupInvitation
  alias Huddlz.Communities.GroupInvitation.EmailToken

  @impl true
  def run(input, _opts, %{actor: actor}) do
    with {:ok, id} <- EmailToken.verify(input.arguments.token),
         {:ok, invitation} <- Ash.get(GroupInvitation, id, authorize?: false) do
      open(invitation, input.arguments.token, actor)
    else
      _ -> {:error, "That invitation isn't available."}
    end
  end

  defp open(%{invitee_id: nil} = invitation, token, actor) do
    invitation
    |> Ash.Changeset.for_update(:claim, %{token: token}, actor: actor)
    |> Ash.update()
  end

  defp open(invitation, _token, actor) do
    Communities.get_my_group_invitation(invitation.id, actor: actor)
  end
end
