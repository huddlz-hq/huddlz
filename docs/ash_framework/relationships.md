# Ash Framework: Working with Relationships

This document covers how to define and work with different types of relationships in Ash Framework. It includes creating, reading, updating, and destroying related data across different relationship types.

## Table of Contents

- [Basic Relationship Types](#basic-relationship-types)
  - [Has Many Relationships](#has-many-relationships)
  - [Belongs To Relationships](#belongs-to-relationships)
  - [Has One Relationships](#has-one-relationships)
  - [Many-to-Many Relationships](#many-to-many-relationships)
- [Creating Related Data](#creating-related-data)
  - [Creating Children from Parent](#creating-children-from-parent)
  - [Creating Parent from Child](#creating-parent-from-child)
  - [Creating Both Together](#creating-both-together)
  - [Working with Many-to-Many](#working-with-many-to-many)
- [Reading Related Data](#reading-related-data)
  - [Loading Related Resources](#loading-related-resources)
  - [Filtering with Relationships](#filtering-with-relationships)
  - [Nested Relationships](#nested-relationships)
- [Deleting Related Records](#deleting-related-records)
  - [Using Data Layer Constraints](#using-data-layer-constraints)
  - [Using Ash Action Hooks](#using-ash-action-hooks)

## Basic Relationship Types

### Has Many Relationships

A has_many relationship indicates that one resource can have multiple instances of another resource.

#### Defining Has Many Relationships

```elixir
# In the Category resource
relationships do
  has_many :articles, Helpcenter.KnowledgeBase.Article do
    description "Relationship with the articles."
    # Specify foreign key column in the destination table
    destination_attribute :category_id
  end
end
```

### Belongs To Relationships

A belongs_to relationship is the inverse of has_many, defined on the child resource.

#### Defining Belongs To Relationships

```elixir
# In the Article resource
relationships do
  belongs_to :category, Helpcenter.KnowledgeBase.Category do
    source_attribute :category_id
  end
end
```

#### Configuring Belongs To in Actions

The simplest way to manage belongs_to relationships is to include the foreign key in the acceptable attributes:

```elixir
# In the Article resource
actions do
  default_accept [
    :title,
    :slug,
    :content,
    :views_count,
    :published,
    :category_id  # Added for category relationship
  ]
  
  defaults [:create, :read, :update, :destroy]
end
```

### Has One Relationships

A has_one relationship is similar to belongs_to, except the reference attribute is on the destination resource instead of the source.

```elixir
# In User resource
relationships do
  has_one :profile, MyApp.Profiles.Profile do
    destination_attribute :user_id
  end
end
```

For detailed information, refer to the [official documentation](https://hexdocs.pm/ash/relationships.html#has-one).

### Many-to-Many Relationships

Many-to-many relationships in Ash are implemented using a join resource/table.

#### Defining Many-to-Many Relationships

```elixir
# In the Article resource
many_to_many :tags, Helpcenter.KnowledgeBase.Tag do
  through Helpcenter.KnowledgeBase.ArticleTag
  source_attribute_on_join_resource :article_id
  destination_attribute_on_join_resource :tag_id
end
```

This defines a relationship that:
- Goes through the ArticleTag join resource
- Uses article_id in the join resource to link to the source (Article)
- Uses tag_id in the join resource to link to the destination (Tag)

## Creating Related Data

### Creating Children from Parent

To create related data (articles under a category):

1. Define a custom action in the parent resource:

```elixir
# In the Category resource
actions do
  update :create_article do
    description "Create an article under a specified category"
    # Set atomic to false for multi-step operations
    require_atomic? false
    # Specify parameter for article attributes
    argument :article_attrs, :map, allow_nil?: false
    change manage_relationship(:article_attrs, :articles, type: :create)
  end
end
```

2. Ensure the child resource (Article) accepts create actions:

```elixir
# In the Article resource
actions do
  default_accept [:title, :slug, :content, :views_count, :published]
  defaults [:create, :read, :update, :destroy]
end
```

3. Create an article under a category:

```elixir
# Get the category first
category = Ash.read_first!(Helpcenter.KnowledgeBase.Category)

# Prepare article data
article_attrs = %{
  title: "Getting Started with Zippiker",
  slug: "getting-started-zippiker",
  content: "Learn how to set up your Zippiker account and configure basic settings.",
  views_count: 1452,
  published: true
}

# Create article under the category
category
|> Ash.Changeset.for_update(:create_article, %{article_attrs: article_attrs})
|> Ash.update()
```

### Creating Parent from Child

To create both the child (Article) and parent (Category) simultaneously:

1. Define an action on the child resource:

```elixir
# In the Article resource
create :create_with_category do
  description "Create an article and its category at the same time"
  argument :category_attrs, :map, allow_nil?: false
  change manage_relationship(:category_attrs, :category, type: :create)
end
```

2. Execute the action:

```elixir
attributes = %{
  title: "Common Issues During Setup and How to Fix Them",
  slug: "setup-common-issues",
  content: "Troubleshooting guide for common challenges faced.",
  category_attrs: %{
    name: "Troubleshooting",
    slug: "troubleshooting",
    description: "Diagnose and fix identified issues"
  }
}

Helpcenter.KnowledgeBase.Article
|> Ash.Changeset.for_create(:create_with_category, attributes)
|> Ash.create()
```

### Creating Both Together

To create a category and its article simultaneously:

1. Define a custom create action in the parent resource:

```elixir
# In the Category resource
create :create_with_article do
  description "Create a Category and an article under it"
  argument :article_attrs, :map, allow_nil?: false
  change manage_relationship(:article_attrs, :articles, type: :create)
end
```

2. Execute the action:

```elixir
# Define attributes for both category and article
attributes = %{
  name: "Features",
  slug: "features",
  description: "Category for features",
  article_attrs: %{
    title: "Compliance Features in Zippiker",
    slug: "compliance-features-zippiker",
    content: "Overview of compliance management features built into Zippiker."
  }
}

# Create both at once
Helpcenter.KnowledgeBase.Category
|> Ash.Changeset.for_create(:create_with_article, attributes)
|> Ash.create()
```

### Working with Many-to-Many

To create an article with tags:

1. Define a custom action in the Article resource:

```elixir
create :create_with_tags do
  description "Create an article with tags"
  argument :tags, {:array, :map}, allow_nil?: false

  change manage_relationship(:tags, :tags,
            on_no_match: :create,
            on_match: :ignore,
            on_missing: :create
          )
end
```

Note the additional options:
- `on_no_match`: What to do when a record doesn't match (create new)
- `on_match`: What to do when a record matches (ignore)
- `on_missing`: What to do when a record is missing (create)

2. Call the action with an array of tag attributes:

```elixir
attributes = %{
  title: "Common Issues During Setup and How to Fix Them",
  slug: "setup-common-issues",
  content: "Troubleshooting guide for common challenges faced.",
  category_id: category.id,
  tags: [%{name: "issues"}, %{name: "solution"}]
}

{:ok, _article} = Helpcenter.KnowledgeBase.Article
  |> Ash.Changeset.for_create(:create_with_tags, attributes)
  |> Ash.create()
```

## Reading Related Data

### Loading Related Resources

To retrieve related data (e.g., articles for a category):

```elixir
category_with_articles =
  Helpcenter.KnowledgeBase.Category
  |> Ash.Query.filter(id == ^category.id)
  |> Ash.Query.load(:articles)  # Tell Ash to load related articles
  |> Ash.read_first!()

# Access articles via
category_with_articles.articles
```

### Filtering with Relationships

Ash allows powerful filtering based on related resources using dot notation.

#### Basic Relationship Filtering

To filter articles by a specific tag:

```elixir
require Ash.Query

Helpcenter.KnowledgeBase.Article
|> Ash.Query.filter(tags.name == "issues")
|> Ash.read!()
```

This returns articles that have the tag "issues".

#### Nested Relationships

You can filter across multiple relationship levels:

```elixir
require Ash.Query

Helpcenter.KnowledgeBase.Category
|> Ash.Query.filter(articles.tags.name == "issues")
|> Ash.read!()
```

This returns categories that have articles with the tag "issues".

The SQL generated for this query would be:

```sql
SELECT
  c0."id",
  c0."name",
  c0."description",
  c0."inserted_at",
  c0."updated_at",
  c0."slug"
FROM "categories" AS c0
 INNER JOIN "articles" AS a1 ON c0."id" = a1."category_id"
 INNER JOIN "article_tags" AS a2 ON a1."id" = a2."article_id"
 INNER JOIN "tags" AS t3 ON t3."id" = a2."tag_id"
WHERE t3."name" = "issues";
```

### Loading Nested Relationships

To load articles and their tags:

```elixir
Helpcenter.KnowledgeBase.Category
|> Ash.Query.filter(articles.tags.name == "issues")
|> Ash.Query.load(articles: :tags)
|> Ash.read!()
```

The special notation `articles: :tags` tells Ash to load articles and then load the tags for each article.

## Deleting Related Records

Ash provides two main approaches for handling the deletion of related records:

### Using Data Layer Constraints

Configure deletion behavior in the postgres section of your resource:

```elixir
# In the Article resource
postgres do
  table "articles"
  repo Helpcenter.Repo

  # Delete this article if related category is deleted
  references do
    reference :category, on_delete: :delete
  end
end
```

Options for `on_delete`:
- `:delete` - Delete related records when the parent is deleted
- `:nilify` - Set foreign key to nil when the parent is deleted
- `:restrict` (default) - Prevent deletion of parent when related records exist

For `:nilify` to work, you also need to allow nil values in the relationship:

```elixir
belongs_to :category, Helpcenter.KnowledgeBase.Category do
  source_attribute :category_id
  # Allow null category_id
  allow_nil? true
end
```

After configuration changes, generate and run migrations:
```
mix ash_postgres.generate_migrations --name add_category_on_delete_to_article
mix ash_postgres.migrate
```

### Using Ash Action Hooks

For more control, you can use hooks to implement custom deletion logic:

```elixir
# In the Article resource
destroy :destroy do
  description "Destroy article and its comments"
  primary? true  # Make this the default destroy action
  require_atomic? false

  # Delete comments before deleting the article
  change before_action(fn changeset, context ->
          require Ash.Query

          # Find and bulk delete all related comments
          %Ash.BulkResult{status: :success} =
            Helpcenter.KnowledgeBase.Comment
            |> Ash.Query.filter(article_id == ^changeset.data.id)
            |> Ash.read!()
            |> Ash.bulk_destroy(:destroy, _condition = %{}, batch_size: 100)

          # Continue with the change
          changeset
        end)
end
```

This approach has some limitations:
- May not guarantee atomicity (all-or-nothing transaction)
- Might not handle deep nested relationships correctly
- May require careful implementation to ensure data integrity

## Key Hooks in Ash

Ash provides several hooks for controlling action workflow:

- `before_action`: Run code before an action starts
- `after_action`: Run code after an action completes
- `before_transaction`: Run code before a transaction starts
- `after_transaction`: Run code after a transaction successfully completes

## Other Common Examples

### Adding Comments to an Article

```elixir
# In the Article resource
update :add_comment do
  description "Add a comment to an article"
  require_atomic? false
  argument :comment, :map, allow_nil?: false
  change manage_relationship(:comment, :comments, type: :create)
end

# Usage
attributes = %{content: "First article content you will see!"}

{:ok, _article} =
  get_article()
  |> Ash.Changeset.for_update(:add_comment, %{comment: attributes})
  |> Ash.update()
```

### Adding Feedback to an Article

```elixir
# In the Article resource
update :add_feedback do
  description "Add a feedback to an article"
  require_atomic? false
  argument :feedback, :map, allow_nil?: false
  change manage_relationship(:feedback, :article_feedbacks, type: :create)
end
```

## Key Insights

1. **Relationship Types**: Ash provides clear patterns for has_many, belongs_to, has_one, and many-to-many relationships.

2. **manage_relationship Change**: This is a key mechanism for working with relationships in Ash:
   - First parameter: The argument that contains the attributes
   - Second parameter: The name of the relationship to manage
   - Third parameter: The options (type: :create, :update, etc.)

3. **Atomic Operations**: Use `require_atomic? false` for multi-step operations.

4. **Loading Related Data**: Use `Ash.Query.load(:relationship_name)` to populate related entities.

5. **Creating Related Records**: Can be done in both directions:
   - Parent → Child: Using manage_relationship in the parent
   - Child → Parent: Using manage_relationship in the child

6. **Arguments in Actions**: Use the `argument` macro to define the structure of inputs to actions.

7. **Relationship Options**: Advanced options like `on_no_match`, `on_match`, and `on_missing` give fine-grained control in many-to-many relationships.

8. **Deletion Strategies**: Choose between data layer constraints and custom hooks for managing related record deletion.