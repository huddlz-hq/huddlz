# Ash Framework: Query Preparations

This document covers how to create reusable query logic in Ash Framework using preparations.

## Table of Contents

- [What Are Query Preparations](#what-are-query-preparations)
- [Types of Preparations](#types-of-preparations)
- [Local Preparations in Actions](#local-preparations-in-actions)
- [Creating Reusable Preparation Modules](#creating-reusable-preparation-modules)
- [Breaking Down Preparations](#breaking-down-preparations-for-better-reusability)
- [Global Preparations](#global-preparations-for-resources)
- [Using Preparations Outside Actions](#using-preparations-outside-actions)
- [Project Structure for Preparations](#project-structure-for-preparations)

## What Are Query Preparations

Query preparations are ways to define reusable read-query logic in Ash Framework. They allow you to apply constraints to queries, such as:

- Filters (WHERE conditions)
- Sorting (ORDER BY)
- Grouping
- Limiting results
- And more

Preparations help DRY up your query logic by making it reusable and composable.

## Types of Preparations

Ash supports two scopes for preparations:

1. **Local Preparations**: Applied to specific actions and confined to that action's scope
2. **Global Preparations**: Applied to all queries of a resource

Additionally, preparations can be implemented as:
- Inline functions within resources
- Standalone modules that can be called from different actions, resources, or queries

## Local Preparations in Actions

Local preparations are defined within an action using the `prepare` or `filter` keywords:

```elixir
# In the Category resource
read :most_recent do
  # Limit results to 5 records
  prepare build(limit: 5)

  # Sort results by insertion date (descending)
  prepare build(sort: [inserted_at: :desc])

  # Filter to include only records created this month
  filter expr(inserted_at >= ^Date.beginning_of_month(Date.utc_today()))
end
```

To use this action:

```elixir
Helpcenter.KnowledgeBase.Category
|> Ash.read!(action: :most_recent)
```

This returns the 5 most recent categories created in the current month, sorted by insertion date.

## Creating Reusable Preparation Modules

To make preparations reusable across multiple actions or resources, extract them into dedicated modules:

```elixir
defmodule Helpcenter.KnowledgeBase.Category.Preparations.MostRecent do
  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _opts, _context) do
    query
    |> Ash.Query.limit(5)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.filter(inserted_at >= ^Date.beginning_of_month(Date.utc_today()))
  end
end
```

Then use the module in your action:

```elixir
read :most_recent do
  prepare Helpcenter.KnowledgeBase.Category.Preparations.MostRecent
end
```

## Breaking Down Preparations for Better Reusability

For maximum reusability, break preparations into smaller, focused modules:

1. **Limit Preparation**:

```elixir
defmodule Helpcenter.Preparations.LimitTo5 do
  use Ash.Resource.Preparation

  def prepare(query, _opts, _context) do
    Ash.Query.limit(query, 5)
  end
end
```

2. **Date Filter Preparation**:

```elixir
defmodule Helpcenter.Preparations.MonthToDate do
  use Ash.Resource.Preparation

  def prepare(query, _opts, _context) do
    # Determine the beginning of the month
    today = Date.utc_today()
    beginning_of_current_month = Date.beginning_of_month(today)

    Ash.Query.filter(query, inserted_at >= ^beginning_of_current_month)
  end
end
```

3. **Sort Preparation**:

```elixir
defmodule Helpcenter.Preparations.OrderByMostRecent do
  use Ash.Resource.Preparation

  def prepare(query, _opts, _context) do
    Ash.Query.sort(query, inserted_at: :desc)
  end
end
```

Using these modular preparations:

```elixir
read :most_recent do
  prepare Helpcenter.Preparations.LimitTo5
  prepare Helpcenter.Preparations.MonthToDate
  prepare Helpcenter.Preparations.OrderByMostRecent
end
```

## Global Preparations for Resources

Apply preparations to all queries of a resource by defining them in the `preparations` block:

```elixir
defmodule Helpcenter.KnowledgeBase.Category do
  use Ash.Resource,
    domain: Helpcenter.KnowledgeBase,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub
  
  preparations do
    prepare Helpcenter.Preparations.LimitTo5
    prepare Helpcenter.Preparations.MonthToDate
    prepare Helpcenter.Preparations.OrderByMostRecent
  end

  # Rest of resource definition...
end
```

Now, all queries on the Category resource will automatically apply these preparations unless explicitly overridden.

## Using Preparations Outside Actions

Preparations can also be applied directly to queries without defining them in actions:

```elixir
opts = []
context = Map.new()

# Apply preparations to a Category query
Helpcenter.KnowledgeBase.Category
|> Helpcenter.Preparations.LimitTo5.prepare(opts, context)
|> Helpcenter.Preparations.MonthToDate.prepare(opts, context)
|> Helpcenter.Preparations.OrderByMostRecent.prepare(opts, context)
|> Ash.read!()

# Apply the same preparations to an Article query
Helpcenter.KnowledgeBase.Article
|> Helpcenter.Preparations.LimitTo5.prepare(opts, context)
|> Helpcenter.Preparations.MonthToDate.prepare(opts, context)
|> Helpcenter.Preparations.OrderByMostRecent.prepare(opts, context)
|> Ash.read!()
```

This approach allows maximum flexibility in applying preparations across different resources.

## Project Structure for Preparations

For better organization, follow these conventions for preparation modules:

1. **Resource-Specific Preparations**: Place in `your_app/resource_name/preparations/preparation_name.ex`
2. **Domain-Wide Preparations**: Place in `your_app/domain_name/preparations/preparation_name.ex`
3. **Application-Wide Preparations**: Place in `your_app/preparations/preparation_name.ex`

For preparations that will be used across multiple resources, prefer more general namespaces:

```elixir
# Instead of this resource-specific path:
Helpcenter.KnowledgeBase.Category.Preparations.LimitTo5

# Use this more general path for shared preparations:
Helpcenter.Preparations.LimitTo5
```

## Key Benefits of Query Preparations

1. **Reusability**: Define query logic once and reuse it across multiple contexts
2. **Maintainability**: Centralize query constraints for easier updates
3. **Composability**: Combine small, focused preparations into more complex queries
4. **Testability**: Test preparation modules independently
5. **Consistency**: Apply the same constraints consistently across resources