defmodule Huddlz.Mcp.Groups do
  alias Ash.Error.Changes.InvalidArgument
  alias Ash.Error.Query.NotFound
  alias Huddlz.Mcp.SearchLocation
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupMember}
  alias Huddlz.Mcp.GroupResult

  @impl true
  def run(%{action: %{name: :search_groups}, arguments: args}, _opts, context) do
    with {:ok, location} <- SearchLocation.resolve(args, context) do
      Communities.search_groups(args[:query], location,
        scope: context,
        page: [limit: args.limit, offset: args.offset]
      )
      |> page_result(args)
    end
  end

  def run(%{action: %{name: :my_groups}, arguments: args}, _opts, context) do
    Communities.groups_for_actor(:all,
      scope: context,
      page: [limit: args.limit, offset: args.offset]
    )
    |> page_result(args)
  end

  def run(%{action: %{name: :get_group}, arguments: args}, _opts, context) do
    with {:ok, group} <- visible_group(args.slug, context) do
      {:ok, GroupResult.from_record(group)}
    end
  end

  def run(%{action: %{name: action}, arguments: %{confirmed: true} = args}, _opts, context) do
    with {:ok, group} <- visible_group(args.slug, context),
         {:ok, membership} <-
           Communities.get_membership_in_group(group.id, scope: context, not_found_error?: false),
         {:ok, state} <- change_membership(action, group, membership, context) do
      {:ok, %{group_id: group.id, slug: group.slug, membership: state}}
    end
  end

  def run(_input, _opts, _context),
    do:
      {:error,
       InvalidArgument.exception(
         field: :confirmed,
         message:
           "Obtain the person's explicit intent for this group before setting confirmed to true."
       )}

  defp visible_group(slug, context) do
    case Communities.get_visible_group_by_slug(slug, scope: context) do
      {:ok, nil} -> {:error, NotFound.exception(resource: Group)}
      other -> other
    end
  end

  defp page_result(result, args) do
    case result do
      {:ok, page} ->
        {:ok,
         %{
           items: Enum.map(page.results, &GroupResult.from_record/1),
           next_offset: if(page.more?, do: args.offset + args.limit)
         }}

      error ->
        error
    end
  end

  defp change_membership(:join_group, group, nil, context) do
    GroupMember
    |> Ash.Changeset.for_create(:join_group, %{group_id: group.id}, scope: context)
    |> Ash.create()
    |> case do
      {:ok, member} -> {:ok, to_string(member.role)}
      error -> error
    end
  end

  defp change_membership(:join_group, _group, member, _context), do: {:ok, to_string(member.role)}
  defp change_membership(:leave_group, _group, nil, _context), do: {:ok, "none"}

  defp change_membership(:leave_group, _group, member, context) do
    member
    |> Ash.Changeset.for_destroy(:leave_group, %{}, scope: context)
    |> Ash.destroy()
    |> case do
      :ok -> {:ok, "none"}
      error -> error
    end
  end
end
