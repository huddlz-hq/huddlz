defmodule Huddlz.Accounts.AccountReport.Actions.ReportGroup do
  @moduledoc """
  Reports the owner of a group through the ordinary `:report` action,
  so the same rules decide who may report whom. The reporter names only
  the group and learns nothing about the account: the action returns no
  report.
  """

  use Ash.Resource.Actions.Implementation

  alias Huddlz.Accounts
  alias Huddlz.Accounts.GroupOwner
  alias Huddlz.Communities.Group

  @impl true
  def run(input, _opts, %{actor: actor}) do
    group_id = input.arguments.group_id

    with {:ok, owner_id} <- GroupOwner.fetch(group_id, actor),
         {:ok, _report} <-
           Accounts.report_account(
             %{
               reported_user_id: owner_id,
               reason: Map.get(input.arguments, :reason),
               details: Map.get(input.arguments, :details),
               source_type: :group,
               source_id: group_id
             },
             actor: actor
           ) do
      :ok
    else
      :error -> {:error, Ash.Error.Query.NotFound.exception(resource: Group)}
      {:error, error} -> {:error, error}
    end
  end
end
