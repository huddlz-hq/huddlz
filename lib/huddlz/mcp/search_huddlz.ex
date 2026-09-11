defmodule Huddlz.Mcp.SearchHuddlz do
  alias Ash.Error.Changes.InvalidArgument
  alias Huddlz.Mcp.SearchLocation
  @moduledoc false
  use Ash.Resource.Actions.Implementation
  alias Huddlz.Communities
  alias Huddlz.Mcp.HuddlResult

  @impl true
  def run(input, _opts, context) do
    args = input.arguments

    with :ok <- validate_window(args),
         {:ok, location} <- SearchLocation.resolve(args, context) do
      Communities.search_huddlz(
        args[:query],
        :upcoming,
        nil,
        location[:search_latitude],
        location[:search_longitude],
        location[:distance_miles],
        args[:relationship],
        scope: context,
        load: HuddlResult.load(),
        query: [
          filter: [and: [from_time(args[:starts_at_or_after]), until_time(args[:starts_before])]],
          sort: [starts_at: :asc, id: :asc]
        ],
        page: [limit: args.limit, offset: args.offset]
      )
      |> case do
        {:ok, page} ->
          {:ok,
           %{
             items: Enum.map(page.results, &HuddlResult.from_record/1),
             next_offset: if(page.more?, do: args.offset + args.limit)
           }}

        error ->
          error
      end
    end
  end

  defp validate_window(%{
         starts_at_or_after: %DateTime{} = first,
         starts_before: %DateTime{} = last
       }) do
    if DateTime.compare(first, last) == :lt,
      do: :ok,
      else:
        {:error,
         InvalidArgument.exception(
           field: :starts_before,
           message: "must be after starts_at_or_after"
         )}
  end

  defp validate_window(_), do: :ok
  defp from_time(nil), do: []
  defp from_time(time), do: [starts_at: [greater_than_or_equal: time]]
  defp until_time(nil), do: []
  defp until_time(time), do: [starts_at: [less_than: time]]
end
