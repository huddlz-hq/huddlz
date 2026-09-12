defmodule Huddlz.Audit.MarkAutomatic do
  @moduledoc "Marks system lifecycle transitions without discarding other audit metadata."
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    if opts[:only_oban?] != true or changeset.context[:private][:ash_oban?] do
      mark_automatic(changeset)
    else
      changeset
    end
  end

  defp mark_automatic(changeset) do
    metadata = Map.put(changeset.context[:paper_trail_metadata] || %{}, :automatic?, true)
    Ash.Changeset.put_context(changeset, :paper_trail_metadata, metadata)
  end
end
