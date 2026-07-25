defmodule Huddlz.Communities.Huddl.Changes.LockedHuddl do
  @moduledoc """
  Loads the current huddl row for trusted attendance and capacity changes.

  The internal read deliberately bypasses viewer visibility filtering and must
  only be called with authorization disabled from a resource change.
  """

  alias Huddlz.Communities.Huddl

  @spec fetch(Ecto.UUID.t(), term()) ::
          {:ok, Huddl.t() | nil} | {:error, Ash.Error.t()}
  def fetch(huddl_id, load \\ []) do
    Huddl
    |> Ash.Query.for_read(:get_for_mutation, %{id: huddl_id})
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.Query.load(load)
    |> Ash.read_one(authorize?: false)
  end

  @spec add_read_error(Ash.Changeset.t(), {:ok, nil} | {:error, Ash.Error.t()}) ::
          Ash.Changeset.t()
  def add_read_error(changeset, {:ok, nil}) do
    Ash.Changeset.add_error(changeset, "This huddl is no longer available")
  end

  def add_read_error(changeset, {:error, error}) do
    Ash.Changeset.add_error(changeset, error)
  end
end
