defmodule Huddlz.Communities.Group.Changes.GenerateSlug do
  @moduledoc """
  Sets the group's slug on create, preferring a caller-supplied slug
  argument over an auto-derived one.

  Order of resolution:
    1. If the caller passed a `slug` argument and it's non-blank, use it.
    2. Otherwise, derive `Slug.slugify(name)`.
    3. If neither slug nor name is available, leave the changeset alone —
       name validation will surface the real error.

  Only runs on create actions; update flows must not silently rewrite
  slugs.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if changeset.action_type == :create do
      case resolve_slug(changeset) do
        nil -> changeset
        slug -> Ash.Changeset.force_change_attribute(changeset, :slug, slug)
      end
    else
      changeset
    end
  end

  defp resolve_slug(changeset) do
    case Ash.Changeset.get_argument(changeset, :slug) do
      slug when is_binary(slug) and slug != "" ->
        slug

      _ ->
        case Ash.Changeset.get_attribute(changeset, :name) do
          nil -> nil
          name -> name |> to_string() |> Slug.slugify()
        end
    end
  end
end
