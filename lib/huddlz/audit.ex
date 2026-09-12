defmodule Huddlz.Audit do
  @moduledoc "Attribution propagation and retention for internal PaperTrail history."

  import Ecto.Query, only: [from: 2]

  @retention_days 90

  def version_resources do
    [Huddlz.Communities, Huddlz.Accounts]
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.filter(fn resource ->
      Code.ensure_loaded?(resource) and function_exported?(resource, :resource_version?, 0)
    end)
  end

  @doc "Carry the initiating actor and supported PaperTrail metadata into a nested action."
  def nested_opts(changeset, metadata \\ %{}) do
    [
      actor: changeset.context[:private][:actor],
      authorize?: false,
      context: %{
        paper_trail_metadata: Map.merge(changeset.context[:paper_trail_metadata] || %{}, metadata)
      }
    ]
  end

  @doc "Delete versions older than the agreed troubleshooting window."
  def prune(now \\ DateTime.utc_now()) do
    cutoff = DateTime.add(now, -@retention_days, :day)

    Enum.each(version_resources(), fn resource ->
      table = AshPostgres.DataLayer.Info.table(resource)

      Huddlz.Repo.delete_all(from(version in table, where: version.version_inserted_at < ^cutoff))
    end)

    :ok
  end
end
