defmodule Huddlz.Audit.MarkAutomatic do
  @moduledoc "Marks system lifecycle transitions without discarding other audit metadata."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    metadata = Map.put(changeset.context[:paper_trail_metadata] || %{}, :automatic?, true)
    Ash.Changeset.put_context(changeset, :paper_trail_metadata, metadata)
  end
end
