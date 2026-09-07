defmodule Huddlz.Communities.GroupInvitation.EmailToken do
  @moduledoc "Proof of possession of an invitation email, separate from public group links."
  alias HuddlzWeb.Endpoint

  @salt "group-invitation-email"
  @max_age 7 * 24 * 60 * 60

  def sign(invitation), do: Phoenix.Token.sign(Endpoint, @salt, invitation.id)

  def verify(token) when is_binary(token),
    do: Phoenix.Token.verify(Endpoint, @salt, token, max_age: @max_age)

  def verify(_token), do: {:error, :invalid}
end
