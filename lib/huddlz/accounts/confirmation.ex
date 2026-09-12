defmodule Huddlz.Accounts.Confirmation do
  @moduledoc """
  The confirmation links behind an account's email address.

  A link is a confirmation token minted by the `:confirm_new_user` strategy
  for the address the account had at the time; the token row remembers that
  address. Links last three days. Minting another (`mint/2`, the resend)
  leaves earlier links alone; completing confirmation discards every stored
  link of the account (`discard_links/1`) so none of them can be used
  again; and a link whose address is no longer the account's is refused by
  the confirm action rather than restoring it (`link_state/1`).
  """

  alias AshAuthentication.{AddOn.Confirmation, Info, Jwt, TokenResource}
  alias Huddlz.Accounts.{Token, User}

  @strategy :confirm_new_user
  @purpose Atom.to_string(@strategy)

  def strategy, do: Info.strategy!(User, @strategy)

  @doc """
  Mint a confirmation link for the account's current address: the same
  token the strategy mints at registration, remembering the address it
  is for. Earlier links are left as they are.
  """
  def mint(%User{} = user) do
    strategy = strategy()

    with {:ok, token, _claims} <-
           Jwt.token_for_user(user, %{"act" => to_string(strategy.confirm_action_name)},
             token_lifetime: strategy.token_lifetime
           ),
         {:ok, _stored} <- remember_address(token, user) do
      {:ok, token}
    end
  end

  defp remember_address(token, user) do
    Token
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_context(%{private: %{ash_authentication?: true}})
    |> Ash.Changeset.for_create(
      :store_confirmation_changes,
      %{token: token, purpose: @purpose, extra_data: %{"email" => to_string(user.email)}},
      upsert?: true
    )
    |> Ash.create()
  end

  @doc """
  What a link can do now: `:usable`, `:previous_address` when the account
  has moved on from the address it was minted for, or `:spent` when it has
  expired, been used, or been discarded.
  """
  def link_state(token) when is_binary(token) do
    with {:ok, %{"sub" => subject, "jti" => jti}, _resource} <- Jwt.verify(token, User),
         false <- TokenResource.token_revoked?(Token, token),
         {:ok, %{"email" => minted_for}} <- Confirmation.Actions.get_changes(strategy(), jti),
         {:ok, %User{} = user} <- AshAuthentication.subject_to_user(subject, User) do
      if same_address?(minted_for, user.email), do: :usable, else: :previous_address
    else
      _ -> :spent
    end
  end

  def link_state(_token), do: :spent

  @doc "Remove every stored confirmation link of the account."
  def discard_links(%User{} = user) do
    Token
    |> Ash.Query.for_read(:read, %{}, authorize?: false)
    |> Ash.bulk_destroy!(:discard_confirmation_links, %{subject: subject(user)},
      authorize?: false,
      strategy: [:atomic, :atomic_batches, :stream],
      return_errors?: true
    )

    :ok
  end

  def purpose, do: @purpose

  defp subject(user), do: AshAuthentication.user_to_subject(user)

  defp same_address?(a, b), do: String.downcase(to_string(a)) == String.downcase(to_string(b))
end
