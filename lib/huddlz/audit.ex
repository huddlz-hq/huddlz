defmodule Huddlz.Audit do
  @moduledoc "Attribution propagation and retention for internal PaperTrail history."

  alias Ash.Domain.Info
  alias Huddlz.Accounts
  alias Huddlz.Communities

  def version_resources do
    [Communities, Accounts]
    |> Enum.flat_map(&Info.resources/1)
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

  @doc "Delete versions older than the two-year audit window."
  def prune(now \\ DateTime.utc_now()) do
    Enum.each(version_resources(), fn resource ->
      Ash.bulk_destroy!(resource, :expire, %{now: now},
        authorize?: false,
        strategy: [:atomic],
        return_errors?: true
      )
    end)

    :ok
  end
end
