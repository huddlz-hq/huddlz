defmodule Huddlz.RateLimit.Keys do
  @moduledoc """
  Bucket-key functions for the auth-action rate limits on `Huddlz.Accounts.User`.

  All three keys are derived from the **email** being acted on, not the caller's IP.
  Email is an argument/attribute of each action, so it is available no matter how the
  action is invoked — the JSON API controller, AshAuthentication's generated routes,
  or the sign-in/register LiveViews over the websocket. (A request-level plug can only
  see the first two, which is why limiting lives on the action.)

  Per-email keying targets the threats where a single email is the victim: password
  guessing against one account, and registration/reset-email bombing of one address.
  IP-based limiting (password spray, bulk signups from one source) is a deliberate
  follow-up — see `docs/api-followups.md`.
  """

  alias Ash.{ActionInput, Changeset, Query}

  @doc "Key for `:sign_in_with_password` (a read action)."
  def sign_in(%Query{} = query, _context) do
    "auth:sign_in:" <> normalize(Query.get_argument(query, :email))
  end

  @doc "Key for `:register_with_password` (a create action)."
  def register(%Changeset{} = changeset, _context) do
    "auth:register:" <> normalize(Changeset.get_attribute(changeset, :email))
  end

  @doc "Key for `:request_password_reset_token` (a generic action)."
  def password_reset(%ActionInput{} = input, _context) do
    "auth:password_reset:" <> normalize(ActionInput.get_argument(input, :email))
  end

  # Email is a `:ci_string`; fold to a stable lower-case string so casing/whitespace
  # variants of the same address share a bucket. A missing email (the action will
  # reject it anyway) buckets together under the empty suffix.
  defp normalize(nil), do: ""
  defp normalize(email), do: email |> to_string() |> String.trim() |> String.downcase()
end
