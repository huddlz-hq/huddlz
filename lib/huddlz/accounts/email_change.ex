defmodule Huddlz.Accounts.EmailChange do
  @moduledoc """
  Approval links are capabilities for one inbox on one pending request. They
  never sign anyone in, and are not exposed in the account's notification feed.
  All state transitions use the User actions, which reload under a row lock.
  """
  alias Huddlz.Accounts.EmailChangeDelivery
  alias Huddlz.Accounts.User
  alias HuddlzWeb.Endpoint
  @salt "email-change-approval-v1"
  @lifetime 3 * 24 * 60 * 60

  defp token(user, side) do
    request = user.pending_email_change
    Phoenix.Token.sign(Endpoint, @salt, {user.id, request["id"], side})
  end

  def verify(token) do
    case Phoenix.Token.verify(Endpoint, @salt, token, max_age: @lifetime) do
      {:ok, {user_id, request_id, side}} when side in ["old", "new"] ->
        {:ok, {user_id, request_id, side}}

      _ ->
        {:error, :invalid}
    end
  end

  def active?(%{"expires_at" => expires_at}), do: expires_at > System.system_time(:second)
  def active?(_), do: false

  def review(token) do
    with {:ok, {user_id, request_id, side}} <- verify(token),
         {:ok, user} <- Ash.get(User, user_id, authorize?: false),
         %{"id" => ^request_id} = pending <- user.pending_email_change,
         true <- active?(pending),
         false <- pending[side <> "_approved"] do
      {:ok, pending}
    else
      _ -> {:error, :invalid}
    end
  end

  def approve(token), do: apply_token(token, :approve_email_change)
  def report(token), do: apply_token(token, :report_email_change)

  defp apply_token(token, action) do
    with {:ok, {user_id, _request_id, _side}} <- verify(token),
         {:ok, user} <- Ash.get(User, user_id, authorize?: false) do
      user
      |> Ash.Changeset.for_update(action, %{token: token})
      |> Ash.update()
    end
  end

  def status(nil), do: nil

  def status(%{"old_approved" => false, "new_approved" => false}),
    do: "Awaiting approval from both addresses"

  def status(%{"old_approved" => false} = pending),
    do: "Awaiting approval from #{pending["old_email"]}"

  def status(pending), do: "Awaiting approval from #{pending["new_email"]}"

  def enqueue(user) do
    ["old", "new"]
    |> Enum.reject(&user.pending_email_change[&1 <> "_approved"])
    |> Enum.reduce_while(:ok, fn side, :ok ->
      case enqueue_approval(user, side) do
        {:ok, _} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp enqueue_approval(user, side) do
    pending = user.pending_email_change

    %{
      "to" => pending[side <> "_email"],
      "old_email" => pending["old_email"],
      "new_email" => pending["new_email"],
      "token" => token(user, side)
    }
    |> EmailChangeDelivery.new()
    |> Oban.insert()
  end
end
