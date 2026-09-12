defmodule Huddlz.Accounts.ConfirmationDestination do
  @moduledoc """
  Remembers the page an unconfirmed person intends to participate on.
  It belongs to the account so existing links and resends work in another
  browser. It is a destination only: visiting it grants no permissions.
  """

  alias Huddlz.Accounts.User

  def validate(path) when is_binary(path) do
    if Regex.match?(
         ~r"\A/(?:groups/[a-z0-9-]+(?:/huddlz/[0-9a-f-]{36})?|invitations/(?:[0-9a-f-]{36}|email/[A-Za-z0-9._~-]+))\z",
         path
       ) and
         path != "/groups/new" do
      path
    end
  end

  def validate(_path), do: nil

  def remember(%User{confirmed_at: nil} = user, path) do
    case validate(path) do
      nil ->
        :ok

      destination ->
        user
        |> Ash.Changeset.for_update(
          :remember_confirmation_destination,
          %{destination: destination},
          actor: user
        )
        |> Ash.update()
    end
  end

  def remember(_user, _path), do: :ok
end
