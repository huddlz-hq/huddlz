defmodule Huddlz.Communities.Group.Checks.OrganizesGroupArgument do
  @moduledoc """
  Authorizes a generic action whose `group_id` argument names a group the
  actor owns or organizes. Generic actions have no record to write an
  expression policy against, so the lookup happens here.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.GroupRoles

  @impl true
  def describe(_opts), do: "actor owns or organizes the group named by group_id"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{action_input: %Ash.ActionInput{} = input}, _opts) do
    group_id = Ash.ActionInput.get_argument(input, :group_id)
    GroupRoles.owns_or_organizes?(actor, group_id, :read_with_archived)
  end

  def match?(_actor, _context, _opts), do: false
end
