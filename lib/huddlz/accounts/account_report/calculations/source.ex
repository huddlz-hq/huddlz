defmodule Huddlz.Accounts.AccountReport.Calculations.Source do
  @moduledoc """
  Resolves report sources in batches using the reader's ordinary community
  permissions. An inaccessible or deleted source has no name or location.
  """
  use Ash.Resource.Calculation

  alias Huddlz.Communities.{Group, Huddl}

  require Ash.Query

  @impl true
  def load(_query, _opts, _context), do: [:source_type, :source_id]

  @impl true
  def calculate(reports, _opts, %{actor: actor}) do
    sources =
      Map.merge(
        huddl_sources(ids(reports, :huddl), actor),
        group_sources(ids(reports, :group), actor)
      )

    Enum.map(reports, &sources[{&1.source_type, &1.source_id}])
  end

  defp ids(reports, type) do
    for %{source_type: ^type, source_id: id} when not is_nil(id) <- reports, uniq: true, do: id
  end

  defp huddl_sources([], _actor), do: %{}

  defp huddl_sources(ids, actor) do
    Huddl
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(id in ^ids)
    |> Ash.Query.load(:group)
    |> Ash.read!()
    |> Map.new(
      &{{:huddl, &1.id}, %{kind: :huddl, id: &1.id, name: &1.title, group_slug: &1.group.slug}}
    )
  end

  defp group_sources([], _actor), do: %{}

  defp group_sources(ids, actor) do
    Group
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read!()
    |> Map.new(&{{:group, &1.id}, %{kind: :group, id: &1.id, name: &1.name, group_slug: &1.slug}})
  end
end
