defmodule Huddlz.Communities.Group.Changes.GenerateSlug do
  @moduledoc """
  Automatically generates a slug from the group name if no slug is provided.
  Only runs on create actions to avoid accidentally changing slugs on updates.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Only generate slug on create if not provided
    if changeset.action.type == :create do
      case {Ash.Changeset.get_attribute(changeset, :slug),
            Ash.Changeset.get_attribute(changeset, :name)} do
        {nil, nil} ->
          # No name provided, let validation handle it
          changeset

        {nil, name} ->
          # Generate slug from name (convert CiString to regular string)
          slug = name |> to_string() |> Slug.slugify()
          Ash.Changeset.change_attribute(changeset, :slug, slug)

        {_slug, _} ->
          # Slug already provided, use it as-is
          changeset
      end
    else
      # Not a create action, don't auto-generate
      changeset
    end
  end
end
