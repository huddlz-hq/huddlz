defmodule Huddlz.Accounts.AccountReport.Actions.ReportOrganizer do
  @moduledoc """
  Reports the organizer of a huddl through the ordinary `:report` action,
  so the same rules decide who may report whom. The reporter names only
  the huddl and learns nothing about the account: the action returns no
  report.
  """

  use Ash.Resource.Actions.Implementation

  alias Huddlz.Accounts
  alias Huddlz.Accounts.HuddlOrganizer
  alias Huddlz.Communities.Huddl

  @impl true
  def run(input, _opts, %{actor: actor}) do
    huddl_id = input.arguments.huddl_id

    with {:ok, organizer_id} <- HuddlOrganizer.fetch(huddl_id, actor),
         {:ok, _report} <-
           Accounts.report_account(
             %{
               reported_user_id: organizer_id,
               reason: Map.get(input.arguments, :reason),
               details: Map.get(input.arguments, :details),
               source_type: :huddl,
               source_id: huddl_id
             },
             actor: actor
           ) do
      :ok
    else
      :error -> {:error, Ash.Error.Query.NotFound.exception(resource: Huddl)}
      {:error, error} -> {:error, error}
    end
  end
end
