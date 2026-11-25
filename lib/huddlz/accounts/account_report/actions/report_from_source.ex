defmodule Huddlz.Accounts.AccountReport.Actions.ReportFromSource do
  @moduledoc """
  Reports an account by naming a group or huddl the actor can see.
  The ordinary account report action checks permission and records the
  source. The caller receives only an acknowledgment on success.
  """

  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Query.NotFound
  alias Huddlz.Accounts
  alias Huddlz.Accounts.{GroupOwner, HuddlOrganizer}
  alias Huddlz.Communities.{Group, Huddl}

  @impl true
  def run(%{action: %{name: :report_group}, arguments: args}, _opts, %{actor: actor}) do
    case GroupOwner.fetch(args.group_id, actor) do
      {:ok, owner_id} -> report(actor, owner_id, {:group, args.group_id}, args)
      :error -> {:error, NotFound.exception(resource: Group)}
    end
  end

  def run(%{action: %{name: :report_organizer}, arguments: args}, _opts, %{actor: actor}) do
    case HuddlOrganizer.fetch(args.huddl_id, actor) do
      {:ok, organizer_id} -> report(actor, organizer_id, {:huddl, args.huddl_id}, args)
      :error -> {:error, NotFound.exception(resource: Huddl)}
    end
  end

  defp report(actor, reported_user_id, {source_type, source_id}, args) do
    attributes = %{
      reported_user_id: reported_user_id,
      source_type: source_type,
      source_id: source_id,
      reason: args[:reason],
      details: args[:details]
    }

    with {:ok, _report} <- Accounts.report_account(attributes, actor: actor), do: :ok
  end
end
