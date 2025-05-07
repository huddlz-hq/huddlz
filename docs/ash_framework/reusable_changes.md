# Ash Framework: Reusable Changes

This document covers how to create reusable change logic in Ash Framework for create and update operations.

## Table of Contents

- [Understanding Changes](#understanding-changes-in-ash-framework)
- [Creating Reusable Change Modules](#creating-reusable-change-modules)
- [Example: Slugify Change](#example-slugify-change)
- [Applying Changes to Resources](#applying-changes-to-resources)
- [Conditional Change Application](#conditional-change-application)
- [Change Options](#change-options)
- [Working with Changeset API](#working-with-changeset-api)
- [Benefits of Reusable Changes](#benefits-of-reusable-changes)

## Understanding Changes in Ash Framework

While preparations handle read-query logic, changes provide similar functionality for create and update operations. Changes allow you to:

- Modify attributes before data is saved
- Sanitize input data
- Generate or transform values
- Implement business rules that affect data creation/updates
- Add new information to records being created or updated

Like preparations, changes can be:
- Applied locally to specific actions
- Applied globally to a resource
- Defined inline or in dedicated modules for reuse

## Creating Reusable Change Modules

To make changes reusable across resources, you can extract them into dedicated modules following Ash conventions:

1. Use `Ash.Resource.Change` behavior
2. Implement the `change/3` function
3. Return the modified changeset

Here's the basic structure of a change module:

```elixir
defmodule Helpcenter.Changes.MyChange do
  use Ash.Resource.Change

  def change(changeset, opts, context) do
    # Modify the changeset
    changeset
  end
end
```

## Example: Slugify Change

Let's implement a reusable change that generates slugs for resources:

```elixir
# lib/helpcenter/changes/slugify.ex
defmodule Helpcenter.Changes.Slugify do
  use Ash.Resource.Change

  @doc """
  Generate and populate a `slug` attribute while inserting a new record
  """
  def change(changeset, _opts, _context) do
    if changeset.action_type == :create do
      changeset
      |> Ash.Changeset.force_change_attribute(:slug, generate_slug(changeset))
    else
      changeset
    end
  end

  # Generate a slug based on the name attribute. If the slug exists already,
  # make it unique by adding `-count` at the end
  defp generate_slug(%{attributes: %{name: name}} = changeset) when not is_nil(name) do
    # 1. Generate a slug based on the name
    slug = get_slug_from_name(name)

    # 2. Add the count if slug exists
    case count_similar_slugs(changeset, slug) do
      {:ok, 0} -> slug
      {:ok, count} -> "#{slug}-#{count}"
      _others -> raise "Could not generate slug"
    end
  end

  # If name is not available, return UUIDv7
  defp generate_slug(_changeset), do: Ash.UUIDv7.generate()

  # Generate a lowercase slug based on the string passed
  defp get_slug_from_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
  end

  defp count_similar_slugs(changeset, slug) do
    require Ash.Query

    changeset.resource
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.count()
  end
end
```

This change:
1. Checks if the action is a create operation
2. Gets the `name` attribute from the changeset
3. Generates a slug by converting the name to lowercase and replacing spaces with hyphens
4. Checks if the slug already exists in the database
5. Makes the slug unique by adding a counter suffix if needed
6. Uses UUIDv7 as a fallback if no name is provided

## Applying Changes to Resources

Once your change is defined, apply it to resources in the `changes` block:

```elixir
defmodule Helpcenter.KnowledgeBase.Category do
  use Ash.Resource,
    domain: Helpcenter.KnowledgeBase,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub

  # Apply the change to all create/update operations
  changes do
    change Helpcenter.Changes.Slugify
  end

  # Rest of resource definition...
end
```

Now, whenever a Category is created, the Slugify change will automatically generate a slug based on its name.

## Conditional Change Application

Changes can be applied conditionally based on action type or other criteria:

```elixir
# Only apply on create
def change(changeset, _opts, _context) do
  if changeset.action_type == :create do
    # Apply change logic
  else
    changeset
  end
end

# Only apply on update
def change(changeset, _opts, _context) do
  if changeset.action_type == :update do
    # Apply change logic
  else
    changeset
  end
end

# Apply based on attribute presence
def change(changeset, _opts, _context) do
  name = Ash.Changeset.get_attribute(changeset, :name)
  
  if name do
    # Apply change logic
  else
    changeset
  end
end
```

## Change Options

Changes can accept options to make them more flexible:

```elixir
defmodule Helpcenter.Changes.Slugify do
  use Ash.Resource.Change

  def change(changeset, opts, _context) do
    # Get options with defaults
    source_field = Keyword.get(opts, :source_field, :name)
    target_field = Keyword.get(opts, :target_field, :slug)
    
    # Use options in change logic
    # ...
  end
end
```

Then apply with options:

```elixir
changes do
  change Helpcenter.Changes.Slugify, source_field: :title, target_field: :url_path
end
```

## Working with Changeset API

Ash provides a robust API for working with changesets:

- `Ash.Changeset.get_attribute(changeset, :field)`: Get an attribute value
- `Ash.Changeset.get_attributes(changeset)`: Get all attributes
- `Ash.Changeset.put_attribute(changeset, :field, value)`: Set an attribute, respecting validations
- `Ash.Changeset.force_change_attribute(changeset, :field, value)`: Set an attribute, bypassing validations
- `Ash.Changeset.after_action(changeset, function)`: Run code after the action completes

## Benefits of Reusable Changes

1. **DRY Code**: Define data transformation logic once and reuse it across resources
2. **Centralized Business Logic**: Keep business rules in one place for easier maintenance
3. **Testability**: Test change modules independently from resources
4. **Composability**: Apply multiple changes in sequence to build complex behaviors
5. **Separation of Concerns**: Decouple data transformation from resource definition

## Advanced Change Patterns

### Before and After Hooks

Changes can run operations before or after the main database operation:

```elixir
defmodule Helpcenter.Changes.LogChange do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn
      {:ok, result}, _changeset ->
        IO.puts("Record created/updated: #{inspect(result)}")
        {:ok, result}

      error, _changeset ->
        IO.puts("Operation failed: #{inspect(error)}")
        error
    end)
  end
end
```

### Managing Related Records

Changes can manage relationships as part of their operation:

```elixir
defmodule Helpcenter.Changes.TrackArticleHistory do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    # Only track history on updates
    if changeset.action_type == :update do
      Ash.Changeset.after_action(changeset, fn
        {:ok, updated_article}, changeset ->
          # Create a history record with the previous version
          history_attrs = %{
            article_id: updated_article.id,
            previous_content: Ash.Changeset.get_attribute(changeset, :content),
            changed_at: DateTime.utc_now()
          }
          
          Helpcenter.KnowledgeBase.ArticleHistory
          |> Ash.Changeset.for_create(:create, history_attrs)
          |> Ash.create()
          
          {:ok, updated_article}
          
        error, _changeset ->
          error
      end)
    else
      changeset
    end
  end
end
```

### Context-Aware Changes

Changes can use the context to access information about the current user or other runtime state:

```elixir
defmodule Helpcenter.Changes.TrackEditor do
  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    # Get current user from context
    current_user = Map.get(context, :user)
    
    if current_user do
      Ash.Changeset.force_change_attribute(changeset, :last_edited_by, current_user.id)
    else
      changeset
    end
  end
end
```

### Validation in Changes

While validations are usually defined separately, changes can include validation logic:

```elixir
defmodule Helpcenter.Changes.ValidateSlug do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    slug = Ash.Changeset.get_attribute(changeset, :slug)
    
    if slug && !String.match?(slug, ~r/^[a-z0-9-]+$/) do
      Ash.Changeset.add_error(changeset, :slug, "must contain only lowercase letters, numbers, and hyphens")
    else
      changeset
    end
  end
end
```