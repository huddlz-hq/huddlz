defmodule Huddlz.Communities.Group.Changes.GenerateSlug do
  @moduledoc """
  Automatically generates a slug from the group name if no slug is provided.
  Only runs on create actions to avoid accidentally changing slugs on updates.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if changeset.action_type == :create do
      changeset
      |> Ash.Changeset.force_change_attribute(:slug, generate_slug(changeset))
    else
      changeset
    end
  end

  defp generate_slug(changeset) do
    case Ash.Changeset.get_attribute(changeset, :name) do
      nil ->
        # No name provided, let validation handle it
        changeset

      name ->
        # Generate slug from name (convert CiString to regular string)
        name |> to_string() |> Slug.slugify()
    end
  end
end
